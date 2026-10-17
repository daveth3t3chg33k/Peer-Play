//! Local HTTP proxy server that streams torrent files with HTTP Range support.
//!
//! `GET /stream/{torrent_id}` looks the torrent up in the shared engine state,
//! opens librqbit's `FileStream` for the selected file, seeks to the requested
//! offset and streams bytes as they are downloaded. `Accept-Ranges: bytes` plus
//! 206 responses let players like ExoPlayer seek and start before the whole file
//! is available.

use crate::engine::EngineInner;
use std::io::SeekFrom;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncSeekExt};
use tokio::sync::RwLock;
use tokio_stream::wrappers::TcpListenerStream;
use tokio_util::io::ReaderStream;
use warp::http::{header, Response, StatusCode};
use warp::hyper::Body;
use warp::Filter;

/// Serve the proxy on an already-bound listener until the process exits.
pub(crate) async fn serve(inner: Arc<RwLock<EngineInner>>, listener: tokio::net::TcpListener) {
    let health = warp::path("health")
        .and(warp::get())
        .map(|| warp::reply::json(&serde_json::json!({ "status": "ok" })));

    let stream_filter = {
        let inner = inner.clone();
        warp::path("stream")
            .and(warp::path::param::<String>())
            .and(warp::get())
            .and(warp::header::optional::<String>("range"))
            .and(warp::any().map(move || inner.clone()))
            .and_then(stream_handler)
    };

    let routes = health.or(stream_filter);
    warp::serve(routes)
        .run_incoming(TcpListenerStream::new(listener))
        .await;
}

async fn stream_handler(
    torrent_id: String,
    range: Option<String>,
    inner: Arc<RwLock<EngineInner>>,
) -> Result<Response<Body>, warp::Rejection> {
    let (handle, file_index, file_len, file_name, download_dir) = {
        let guard = inner.read().await;
        match guard.torrents.get(&torrent_id) {
            Some(entry) => (
                entry.handle.clone(),
                entry.file_index,
                entry.file_len,
                entry.file_name.clone(),
                guard.download_dir.clone(),
            ),
            None => {
                eprintln!("[proxy] 404: unknown torrent {torrent_id}");
                return Err(warp::reject::not_found());
            }
        }
    };

    crate::engine::dlog(
        &download_dir,
        &format!(
            "[proxy] request {file_name} range={:?} state='{}'",
            range,
            handle.stats().state
        ),
    );

    if file_len == 0 {
        eprintln!("[proxy] 404: file_len is 0 for {file_name}");
        crate::engine::dlog(&download_dir, "[proxy] 404: file_len is 0");
        return Err(warp::reject::not_found());
    }

    let (start, end, partial) = parse_range(range.as_deref(), file_len);
    if start >= file_len || start > end {
        return Ok(Response::builder()
            .status(StatusCode::RANGE_NOT_SATISFIABLE)
            .header(header::CONTENT_RANGE, format!("bytes */{file_len}"))
            .body(Body::empty())
            .expect("valid 416 response"));
    }
    let content_len = end - start + 1;

    let state_now = handle.stats().state.to_string();
    let mut file_stream = handle.stream(file_index).await.map_err(|e| {
        crate::engine::dlog(
            &download_dir,
            &format!(
                "[proxy] 404: stream() failed for {file_name} (index {file_index}, len {file_len}, \
                 state='{state_now}'): {e}"
            ),
        );
        warp::reject::not_found()
    })?;
    if start > 0 {
        file_stream.seek(SeekFrom::Start(start)).await.map_err(|e| {
            eprintln!("[proxy] 404: seek failed for {file_name}: {e}");
            warp::reject::not_found()
        })?;
    }

    let body = Body::wrap_stream(ReaderStream::new(file_stream.take(content_len)));
    let mime = mime_guess::from_path(&file_name).first_or_octet_stream();

    let mut builder = Response::builder()
        .header(header::CONTENT_TYPE, mime.as_ref())
        .header(header::ACCEPT_RANGES, "bytes")
        .header(header::CONTENT_LENGTH, content_len.to_string());

    builder = if partial {
        builder
            .status(StatusCode::PARTIAL_CONTENT)
            .header(
                header::CONTENT_RANGE,
                format!("bytes {}-{}/{}", start, end, file_len),
            )
    } else {
        builder.status(StatusCode::OK)
    };

    builder.body(body).map_err(|_| warp::reject::not_found())
}

/// Parse a single-range `Range` header. Returns `(start, end_inclusive, partial)`.
fn parse_range(range: Option<&str>, len: u64) -> (u64, u64, bool) {
    let last = len.saturating_sub(1);
    let Some(header_value) = range else {
        return (0, last, false);
    };
    let trimmed = header_value.trim();
    let Some(spec) = trimmed.strip_prefix("bytes=") else {
        return (0, last, false);
    };
    let spec = spec.split(',').next().unwrap_or("").trim();

    // Suffix range: bytes=-N (last N bytes).
    if let Some(suffix) = spec.strip_prefix('-') {
        if let Ok(n) = suffix.parse::<u64>() {
            if n == 0 {
                return (last, last, true);
            }
            return (len.saturating_sub(n), last, true);
        }
        return (0, last, false);
    }

    let mut parts = spec.splitn(2, '-');
    let start = parts
        .next()
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(0);
    let end = parts
        .next()
        .and_then(|s| {
            if s.is_empty() {
                None
            } else {
                s.parse::<u64>().ok()
            }
        })
        .unwrap_or(last)
        .min(last);
    (start, end, true)
}

#[cfg(test)]
mod tests {
    use super::parse_range;

    #[test]
    fn no_header_is_full_file() {
        assert_eq!(parse_range(None, 1000), (0, 999, false));
    }

    #[test]
    fn explicit_range() {
        assert_eq!(parse_range(Some("bytes=0-99"), 1000), (0, 99, true));
        assert_eq!(parse_range(Some("bytes=100-"), 1000), (100, 999, true));
    }

    #[test]
    fn suffix_range() {
        assert_eq!(parse_range(Some("bytes=-100"), 1000), (900, 999, true));
    }

    #[test]
    fn clamps_end_to_file_length() {
        assert_eq!(parse_range(Some("bytes=0-5000"), 1000), (0, 999, true));
    }
}
