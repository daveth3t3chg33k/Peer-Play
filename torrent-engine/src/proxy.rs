//! Local HTTP proxy server for streaming torrent content.

use std::net::SocketAddr;
use warp::Filter;

/// Start a local HTTP proxy server that serves torrent stream data.
pub async fn start_proxy_server(
    port: u16,
    _download_dir: String,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr: SocketAddr = ([127, 0, 0, 1], port).into();

    let health = warp::path("health")
        .and(warp::get())
        .map(|| warp::reply::json(&serde_json::json!({"status": "ok"})));

    let list = warp::path("torrents")
        .and(warp::get())
        .map(|| warp::reply::json(&serde_json::json!({"torrents": []})));

    let stream = warp::path("stream")
        .and(warp::path::param::<String>())
        .and(warp::get())
        .map(|torrent_id: String| {
            warp::reply::json(&serde_json::json!({
                "torrent_id": torrent_id,
                "message": "Stream endpoint ready",
            }))
        });

    let routes = health.or(list).or(stream).recover(|_err: warp::Rejection| async move {
        Ok::<_, warp::Rejection>(warp::reply::with_status(
            warp::reply::json(&serde_json::json!({"error": "not found"})),
            warp::http::StatusCode::NOT_FOUND,
        ))
    });

    log::info!("PeerPlay proxy server listening on {}", addr);
    warp::serve(routes).run(addr).await;
    Ok(())
}
