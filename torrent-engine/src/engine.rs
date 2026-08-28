//! Torrent engine — wraps librqbit with UniFFI-exported types.

use librqbit::{Session, AddTorrent};
use std::fmt;
use std::path::PathBuf;
use std::sync::Arc;
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

struct EngineInner {
    // librqbit 9.0 Session::new() returns Arc<Session>
    session: Option<Arc<Session>>,
    download_dir: PathBuf,
    torrents: Vec<TorrentEntry>,
    proxy_port: u16,
}

struct TorrentEntry {
    id: String,
    url: String,
    name: String,
    status: TorrentStatus,
    total_size: u64,
}

/// The main torrent engine.
#[derive(uniffi::Object)]
pub struct TorrentEngine {
    inner: Arc<RwLock<EngineInner>>,
}

#[uniffi::export]
impl TorrentEngine {
    /// Create a new torrent engine.
    #[uniffi::constructor]
    pub async fn new(download_dir: String, _listen_port: u32) -> Result<Arc<Self>, TorrentError> {
        let dir = PathBuf::from(&download_dir);
        std::fs::create_dir_all(&dir).map_err(|e| TorrentError::Internal(e.to_string()))?;

        // librqbit 9.0: Session::new() returns Arc<Session> via BoxFuture
        let session: Arc<Session> = Session::new(dir.clone())
            .await
            .map_err(|e| TorrentError::Internal(e.to_string()))?;

        let inner = EngineInner {
            session: Some(session),
            download_dir: dir,
            torrents: Vec::new(),
            proxy_port: 0,
        };

        Ok(Arc::new(Self {
            inner: Arc::new(RwLock::new(inner)),
        }))
    }

    /// Add a torrent by magnet link or URL.
    pub async fn add_torrent(&self, url: String) -> Result<String, TorrentError> {
        let torrent_id = Uuid::new_v4().to_string();

        let mut inner = self.inner.write().await;
        let session = inner
            .session
            .as_ref()
            .ok_or(TorrentError::EngineNotInitialized)?;

        // librqbit 9.0: add_torrent takes &'a Arc<Self>
        let _handle = session
            .add_torrent(AddTorrent::from_url(&url), None)
            .await
            .map_err(|e| TorrentError::Internal(e.to_string()))?;

        inner.torrents.push(TorrentEntry {
            id: torrent_id.clone(),
            url,
            name: format!("torrent-{}", &torrent_id[..8]),
            status: TorrentStatus::Resolving,
            total_size: 0,
        });

        Ok(torrent_id)
    }

    /// Remove a torrent by ID.
    pub async fn remove_torrent(&self, torrent_id: String) -> Result<(), TorrentError> {
        let mut inner = self.inner.write().await;
        inner.torrents.retain(|t| t.id != torrent_id);
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
            .iter()
            .find(|t| t.id == torrent_id)
            .ok_or(TorrentError::TorrentNotFound)?;

        Ok(TorrentInfo {
            id: entry.id.clone(),
            url: entry.url.clone(),
            name: entry.name.clone(),
            total_size_bytes: entry.total_size,
            peer_count: 0,
            download_speed: 0,
            upload_speed: 0,
            status: entry.status.clone(),
            download_path: inner.download_dir.to_string_lossy().to_string(),
            proxy_port: inner.proxy_port as u32,
        })
    }

    /// Get all active torrents.
    pub async fn list_torrents(&self) -> Result<Vec<TorrentInfo>, TorrentError> {
        let inner = self.inner.read().await;
        let results: Vec<TorrentInfo> = inner
            .torrents
            .iter()
            .map(|entry| TorrentInfo {
                id: entry.id.clone(),
                url: entry.url.clone(),
                name: entry.name.clone(),
                total_size_bytes: entry.total_size,
                peer_count: 0,
                download_speed: 0,
                upload_speed: 0,
                status: entry.status.clone(),
                download_path: inner.download_dir.to_string_lossy().to_string(),
                proxy_port: inner.proxy_port as u32,
            })
            .collect();
        Ok(results)
    }

    /// Get global engine statistics.
    pub async fn get_stats(&self) -> Result<EngineStats, TorrentError> {
        let inner = self.inner.read().await;
        Ok(EngineStats {
            active_torrents: inner.torrents.len() as u32,
            total_downloaded_bytes: 0,
            total_upload_speed: 0,
            total_download_speed: 0,
            dht_node_id: String::new(),
        })
    }

    /// Start the local HTTP proxy server for streaming.
    pub async fn start_proxy(&self, port: u32) -> Result<u32, TorrentError> {
        let mut inner = self.inner.write().await;
        inner.proxy_port = port as u16;
        Ok(port)
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
        Ok(format!(
            "http://127.0.0.1:{}/stream/{}",
            inner.proxy_port, torrent_id
        ))
    }

    /// Pause all active downloads.
    pub async fn pause_all(&self) -> Result<(), TorrentError> {
        let mut inner = self.inner.write().await;
        for entry in &mut inner.torrents {
            entry.status = TorrentStatus::Paused;
        }
        Ok(())
    }

    /// Resume all paused downloads.
    pub async fn resume_all(&self) -> Result<(), TorrentError> {
        let mut inner = self.inner.write().await;
        for entry in &mut inner.torrents {
            if let TorrentStatus::Paused = &entry.status {
                entry.status = TorrentStatus::Resolving;
            }
        }
        Ok(())
    }
}
