//! PeerPlay Torrent Engine

mod engine;
mod proxy;

pub use engine::{TorrentEngine, TorrentStatus, TorrentInfo, EngineStats, TorrentError};

// This macro generates the UniFFI scaffolding code including UniFfiTag
// which is required by #[uniffi::export] and other proc macros.
uniffi::setup_scaffolding!();
