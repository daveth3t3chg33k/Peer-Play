//! Diagnostic: add a magnet, wait for peers/metadata, then range-fetch bytes
//! from the local streaming proxy. Usage:
//!
//! ```text
//! cargo run --release --example stream_check -- "<magnet>" [timeout_secs]
//! ```

use peerplay_torrent_engine::TorrentEngine;
use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::{Duration, Instant};

fn main() {
    let mut args = std::env::args().skip(1);
    let magnet = args.next().expect("usage: stream_check <magnet> [timeout_secs]");
    let timeout: u64 = args.next().and_then(|s| s.parse().ok()).unwrap_or(45);

    let dir = std::env::temp_dir().join("pp_stream_check");
    if std::env::var("PP_KEEP").is_err() {
        let _ = std::fs::remove_dir_all(&dir);
    }
    std::fs::create_dir_all(&dir).expect("create dir");

    let engine =
        TorrentEngine::new(dir.to_string_lossy().to_string(), 0).expect("create engine");
    let rt = tokio::runtime::Runtime::new().expect("runtime");

    let port = rt.block_on(engine.start_proxy(0)).expect("start proxy");
    println!("[check] proxy listening on 127.0.0.1:{port}");

    let t0 = Instant::now();
    let id = rt
        .block_on(engine.add_torrent(magnet))
        .expect("add torrent");
    println!("[check] added {id} in {:.1}s", t0.elapsed().as_secs_f64());

    // Wait for peers + real throughput while reporting status.
    let deadline = Instant::now() + Duration::from_secs(timeout);
    let mut saw_speed = false;
    loop {
        let info = rt
            .block_on(engine.get_torrent_status(id.clone()))
            .expect("status");
        let pct = match &info.status {
            peerplay_torrent_engine::TorrentStatus::Downloading { progress_percent } => {
                *progress_percent
            }
            peerplay_torrent_engine::TorrentStatus::Streaming { progress_percent } => {
                *progress_percent
            }
            peerplay_torrent_engine::TorrentStatus::Completed => 100.0,
            _ => 0.0,
        };
        println!(
            "[check] t={:>4.1}s peers={} down={}B/s size={} pct={:.2} status={:?}",
            t0.elapsed().as_secs_f64(),
            info.peer_count,
            info.download_speed,
            info.total_size_bytes,
            pct,
            info.status
        );
        if info.download_speed > 0 {
            saw_speed = true;
        }
        // Once we have peers and are actively pulling bytes, give it a moment
        // to buffer, then try to stream.
        if saw_speed && info.download_speed > 0 {
            std::thread::sleep(Duration::from_secs(3));
            break;
        }
        if Instant::now() >= deadline {
            println!("[check] WARNING: no peer throughput before timeout");
            break;
        }
        std::thread::sleep(Duration::from_millis(500));
    }

    // Range-fetch the first 256 KiB through the proxy, retrying while the
    // first pieces are still being downloaded.
    let mut body_len = 0usize;
    let mut head = String::new();
    for attempt in 0..10 {
        let req = format!(
            "GET /stream/{id} HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: bytes=0-262143\r\nConnection: close\r\n\r\n"
        );
        let mut sock = TcpStream::connect(("127.0.0.1", port as u16)).expect("connect proxy");
        sock.set_read_timeout(Some(Duration::from_secs(20))).unwrap();
        sock.write_all(req.as_bytes()).expect("write request");
        let mut buf = Vec::new();
        let _ = sock.read_to_end(&mut buf);
        let head_end = buf
            .windows(4)
            .position(|w| w == b"\r\n\r\n")
            .map(|p| p + 4)
            .unwrap_or(0);
        head = String::from_utf8_lossy(&buf[..head_end]).to_string();
        body_len = buf.len().saturating_sub(head_end);
        println!("[check] attempt {attempt}: body bytes = {body_len}");
        if body_len >= 262144 {
            break;
        }
        std::thread::sleep(Duration::from_secs(3));
    }
    println!("[check] --- proxy response head ---\n{head}");
    println!("[check] body bytes received: {body_len}");
    println!(
        "[check] VERDICT: {}",
        if body_len >= 262144 {
            "STREAMED FULL 256KiB OK"
        } else if body_len > 0 {
            "PARTIAL BYTES"
        } else {
            "NO BYTES"
        }
    );
}
