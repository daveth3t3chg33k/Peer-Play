//! Torrent engine — wraps librqbit with UniFFI-exported types.
//!
//! All librqbit work runs on a single process-wide tokio runtime (`runtime()`)
//! so that the background tasks librqbit spawns stay alive for the lifetime of
//! the process. The previous implementation created a throwaway runtime and
//! dropped it immediately, which silently killed every torrent.

use librqbit::{
    AddTorrent, AddTorrentOptions, ManagedTorrent, Session, SessionOptions,
};
use std::collections::HashMap;
use std::fmt;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock};
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::sync::RwLock;
use uuid::Uuid;

/// UniFFI-compatible error type.
#[derive(Debug, Clone, uniffi::Error)]
#[uniffi(flat_error)]
pub enum TorrentError {
    EngineNotInitialized,
    TorrentNotFound,
    ProxyNotStarted,
    Internal(String),
}

impl fmt::Display for TorrentError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EngineNotInitialized => write!(f, "Engine not initialized"),
            Self::TorrentNotFound => write!(f, "Torrent not found"),
            Self::ProxyNotStarted => write!(f, "Proxy server not started"),
            Self::Internal(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl std::error::Error for TorrentError {}

impl From<anyhow::Error> for TorrentError {
    fn from(e: anyhow::Error) -> Self {
        TorrentError::Internal(e.to_string())
    }
}

/// Represents the status of a torrent download.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum TorrentStatus {
    Resolving,
    DownloadingMetadata,
    Downloading { progress_percent: f64 },
    Streaming { progress_percent: f64 },
    Completed,
    Paused,
    Error { message: String },
}

/// Information about a torrent.
#[derive(Debug, Clone, uniffi::Record)]
pub struct TorrentInfo {
    pub id: String,
    pub url: String,
    pub name: String,
    pub total_size_bytes: u64,
    pub peer_count: u32,
    pub download_speed: u64,
    pub upload_speed: u64,
    pub status: TorrentStatus,
    pub download_path: String,
    pub proxy_port: u32,
}

/// Global engine statistics.
#[derive(Debug, Clone, uniffi::Record)]
pub struct EngineStats {
    pub active_torrents: u32,
    pub total_downloaded_bytes: u64,
    pub total_upload_speed: u64,
    pub total_download_speed: u64,
    pub dht_node_id: String,
}

/// The single tokio runtime every async operation is scheduled on.
pub(crate) fn runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .thread_name("peerplay-torrent")
            .build()
            .expect("failed to build torrent runtime")
    })
}

/// A torrent we manage, plus the file chosen for streaming.
pub(crate) struct TorrentEntry {
    pub handle: Arc<ManagedTorrent>,
    pub url: String,
    pub name: String,
    pub file_index: usize,
    pub file_name: String,
    pub file_len: u64,
}

/// Engine state shared with the local proxy server.
pub(crate) struct EngineInner {
    pub session: Option<Arc<Session>>,
    pub download_dir: PathBuf,
    pub torrents: HashMap<String, TorrentEntry>,
    pub proxy_port: u16,
}

/// The main torrent engine.
#[derive(uniffi::Object)]
pub struct TorrentEngine {
    inner: Arc<RwLock<EngineInner>>,
}

/// Append a diagnostic line to `<dir>/peerplay_engine.log`.
///
/// Rust's `stderr` is not captured by Android's logcat for app processes, so
/// during bring-up we mirror key diagnostics to a file inside the engine's
/// download directory where they can be pulled with `adb`.
pub(crate) fn dlog(dir: &Path, msg: &str) {
    use std::io::Write;
    let path = dir.join("peerplay_engine.log");
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0);
        let _ = writeln!(f, "[{ts}] {msg}");
    }
}

fn is_video_file(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    const EXTS: [&str; 9] = [
        ".mp4", ".mkv", ".m4v", ".avi", ".mov", ".webm", ".ts", ".mpg", ".mpeg",
    ];
    EXTS.iter().any(|ext| lower.ends_with(ext))
}

fn select_stream_file(handle: &Arc<ManagedTorrent>) -> Result<(usize, String, u64), TorrentError> {
    let picked = handle.with_metadata(|m| {
        let mut best_video: Option<(usize, u64, String)> = None;
        let mut best_any: Option<(usize, u64, String)> = None;
        for (i, f) in m.file_infos.iter().enumerate() {
            let name = f.relative_filename.to_string_lossy().to_string();
            if is_video_file(&name) && best_video.as_ref().map_or(true, |(_, l, _)| f.len > *l) {
                best_video = Some((i, f.len, name.clone()));
            }
            if best_any.as_ref().map_or(true, |(_, l, _)| f.len > *l) {
                best_any = Some((i, f.len, name));
            }
        }
        best_video.or(best_any)
    });

    match picked {
        Ok(Some((index, len, name))) => Ok((index, name, len)),
        Ok(None) => Err(TorrentError::Internal("torrent contains no files".into())),
        Err(e) => Err(TorrentError::Internal(e.to_string())),
    }
}

fn status_from(handle: &Arc<ManagedTorrent>) -> (TorrentStatus, u64, u32, u64, u64) {
    let stats = handle.stats();
    let (peer_count, down, up) = match stats.live.as_ref() {
        Some(live) => (
            live.snapshot.peer_stats.live,
            live.download_speed.as_bytes(),
            live.upload_speed.as_bytes(),
        ),
        None => (0, 0, 0),
    };
    let progress = if stats.total_bytes > 0 {
        stats.progress_bytes as f64 / stats.total_bytes as f64 * 100.0
    } else {
        0.0
    };
    let status = if let Some(err) = stats.error.clone() {
        TorrentStatus::Error { message: err }
    } else if stats.finished {
        TorrentStatus::Completed
    } else if handle.is_paused() {
        TorrentStatus::Paused
    } else if stats.total_bytes == 0 {
        TorrentStatus::DownloadingMetadata
    } else {
        TorrentStatus::Downloading {
            progress_percent: progress,
        }
    };
    (status, stats.total_bytes, peer_count, down, up)
}

impl EngineInner {
    fn info_for(&self, id: &str, entry: &TorrentEntry) -> TorrentInfo {
        let (status, total, peers, down, up) = status_from(&entry.handle);
        TorrentInfo {
            id: id.to_string(),
            url: entry.url.clone(),
            name: entry.name.clone(),
            total_size_bytes: total,
            peer_count: peers,
            download_speed: down,
            upload_speed: up,
            status,
            download_path: self.download_dir.to_string_lossy().to_string(),
            proxy_port: self.proxy_port as u32,
        }
    }
}

#[uniffi::export]
impl TorrentEngine {
    /// Create a new torrent engine.
    #[uniffi::constructor]
    pub fn new(download_dir: String, _listen_port: u32) -> Result<Arc<Self>, TorrentError> {
        let dir = PathBuf::from(&download_dir);
        std::fs::create_dir_all(&dir).map_err(|e| TorrentError::Internal(e.to_string()))?;

        let rt = runtime();
        let session = rt.block_on(async {
            // Prefer DHT (best peer discovery); fall back to trackers-only if the
            // UDP socket cannot be bound (some locked-down devices/emulators).
            match Session::new_with_opts(dir.clone(), SessionOptions::default()).await {
                Ok(s) => Ok(s),
                Err(_) => {
                    let opts = SessionOptions {
                        dht: None,
                        ..Default::default()
                    };
                    Session::new_with_opts(dir.clone(), opts).await
                }
            }
        })?;

        let inner = EngineInner {
            session: Some(session),
            download_dir: dir,
            torrents: HashMap::new(),
            proxy_port: 0,
        };

        Ok(Arc::new(Self {
            inner: Arc::new(RwLock::new(inner)),
        }))
    }

    /// Add a torrent by magnet link or URL and pick its streamable file.
    pub async fn add_torrent(&self, url: String) -> Result<String, TorrentError> {
        let session = self
            .inner
            .read()
            .await
            .session
            .clone()
            .ok_or(TorrentError::EngineNotInitialized)?;

        let id = Uuid::new_v4().to_string();
        let url_for_add = url.clone();

        let handle = runtime()
            .spawn(async move {
                // `overwrite: true` lets us re-add a torrent whose partial files
                // are already on disk (retry, resume, or replaying a title).
                // Without it librqbit fails with "error creating a new file
                // (because allow_overwrite = false)" and playback dies.
                let opts = AddTorrentOptions {
                    overwrite: true,
                    ..Default::default()
                };
                let response = session
                    .add_torrent(AddTorrent::from_url(&url_for_add), Some(opts))
                    .await?;
                let handle = response
                    .into_handle()
                    .ok_or_else(|| anyhow::anyhow!("torrent was not added"))?;
                // Wait up to ~60s for metadata (file list) to resolve.
                for _ in 0..120 {
                    if handle.with_metadata(|_| ()).is_ok() {
                        break;
                    }
                    tokio::time::sleep(Duration::from_millis(500)).await;
                }
                anyhow::Ok(handle)
            })
            .await
            .map_err(|e| TorrentError::Internal(e.to_string()))?
            .map_err(|e| TorrentError::Internal(e.to_string()))?;

        let (file_index, file_name, file_len) = select_stream_file(&handle)?;
        let name = handle.name().unwrap_or_else(|| format!("torrent-{}", &id[..8]));
        {
            let stats = handle.stats();
            let line = format!(
                "[engine] added '{name}': file[{file_index}]={file_name} len={file_len} \
                 total={} progress={} finished={} err={:?} state='{}' paused={} file_progress={:?}",
                stats.total_bytes,
                stats.progress_bytes,
                stats.finished,
                stats.error,
                stats.state,
                handle.is_paused(),
                stats.file_progress
            );
            let dir = self.inner.read().await.download_dir.clone();
            dlog(&dir, &line);
        }

        let mut inner = self.inner.write().await;
        inner.torrents.insert(
            id.clone(),
            TorrentEntry {
                handle,
                url,
                name,
                file_index,
                file_name,
                file_len,
            },
        );

        Ok(id)
    }

    /// Remove a torrent by ID.
    pub async fn remove_torrent(&self, torrent_id: String) -> Result<(), TorrentError> {
        let mut inner = self.inner.write().await;
        inner.torrents.remove(&torrent_id);
        Ok(())
    }

    /// Get the status of a specific torrent.
    pub async fn get_torrent_status(
        &self,
        torrent_id: String,
    ) -> Result<TorrentInfo, TorrentError> {
        let inner = self.inner.read().await;
        let entry = inner
            .torrents
            .get(&torrent_id)
            .ok_or(TorrentError::TorrentNotFound)?;
        Ok(inner.info_for(&torrent_id, entry))
    }

    /// Get all active torrents.
    pub async fn list_torrents(&self) -> Result<Vec<TorrentInfo>, TorrentError> {
        let inner = self.inner.read().await;
        Ok(inner
            .torrents
            .iter()
            .map(|(id, entry)| inner.info_for(id, entry))
            .collect())
    }

    /// Get global engine statistics.
    pub async fn get_stats(&self) -> Result<EngineStats, TorrentError> {
        let inner = self.inner.read().await;
        let mut downloaded = 0u64;
        let mut down = 0u64;
        let mut up = 0u64;
        for entry in inner.torrents.values() {
            let stats = entry.handle.stats();
            downloaded += stats.progress_bytes;
            if let Some(live) = stats.live.as_ref() {
                down += live.download_speed.as_bytes();
                up += live.upload_speed.as_bytes();
            }
        }
        Ok(EngineStats {
            active_torrents: inner.torrents.len() as u32,
            total_downloaded_bytes: downloaded,
            total_upload_speed: up,
            total_download_speed: down,
            dht_node_id: String::new(),
        })
    }

    /// Start the local HTTP proxy server for streaming. Returns the bound port.
    pub async fn start_proxy(&self, port: u32) -> Result<u32, TorrentError> {
        {
            let inner = self.inner.read().await;
            if inner.proxy_port != 0 {
                return Ok(inner.proxy_port as u32);
            }
        }

        // Bind first so callers get the real port when 0 (auto) is requested.
        let requested = port as u16;
        let std_listener = std::net::TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], requested)))
            .map_err(|e| TorrentError::Internal(e.to_string()))?;
        std_listener
            .set_nonblocking(true)
            .map_err(|e| TorrentError::Internal(e.to_string()))?;
        let actual_port = std_listener
            .local_addr()
            .map_err(|e| TorrentError::Internal(e.to_string()))?
            .port();
        // `TcpListener::from_std` registers the socket with the Tokio reactor, so
        // it needs an active runtime context on the current thread. This function
        // is polled by the foreign (Kotlin) executor, which is not a Tokio thread,
        // hence entering the runtime explicitly. Without this the proxy failed to
        // start with "there is no reactor running".
        let listener = {
            let _guard = runtime().enter();
            tokio::net::TcpListener::from_std(std_listener)
                .map_err(|e| TorrentError::Internal(e.to_string()))?
        };

        let shared = self.inner.clone();
        runtime().spawn(async move {
            crate::proxy::serve(shared, listener).await;
        });

        let mut inner = self.inner.write().await;
        inner.proxy_port = actual_port;
        Ok(actual_port as u32)
    }

    /// Stop the local HTTP proxy server.
    pub async fn stop_proxy(&self) -> Result<(), TorrentError> {
        let mut inner = self.inner.write().await;
        inner.proxy_port = 0;
        Ok(())
    }

    /// Get the local HTTP URL for streaming a specific torrent.
    pub async fn get_stream_url(&self, torrent_id: String) -> Result<String, TorrentError> {
        let inner = self.inner.read().await;
        if inner.proxy_port == 0 {
            return Err(TorrentError::ProxyNotStarted);
        }
        if !inner.torrents.contains_key(&torrent_id) {
            return Err(TorrentError::TorrentNotFound);
        }
        Ok(format!(
            "http://127.0.0.1:{}/stream/{}",
            inner.proxy_port, torrent_id
        ))
    }

    /// Pause all active downloads.
    pub async fn pause_all(&self) -> Result<(), TorrentError> {
        let (session, handles) = {
            let inner = self.inner.read().await;
            let session = inner
                .session
                .clone()
                .ok_or(TorrentError::EngineNotInitialized)?;
            let handles: Vec<_> = inner
                .torrents
                .values()
                .map(|e| e.handle.clone())
                .collect();
            (session, handles)
        };
        for handle in handles {
            let _ = session.pause(&handle).await;
        }
        Ok(())
    }

    /// Resume all paused downloads.
    pub async fn resume_all(&self) -> Result<(), TorrentError> {
        let (session, handles) = {
            let inner = self.inner.read().await;
            let session = inner
                .session
                .clone()
                .ok_or(TorrentError::EngineNotInitialized)?;
            let handles: Vec<_> = inner
                .torrents
                .values()
                .map(|e| e.handle.clone())
                .collect();
            (session, handles)
        };
        for handle in handles {
            let _ = session.unpause(&handle).await;
        }
        Ok(())
    }
}

/// Convenience helper used by tests/tools: does the given path look streamable?
#[allow(dead_code)]
pub(crate) fn path_is_video(path: &Path) -> bool {
    is_video_file(&path.to_string_lossy())
}
