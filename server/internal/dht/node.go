package dht

import (
	"context"
	"encoding/hex"
	"log/slog"
	"sync"
	"time"
)

// TorrentInfo holds metadata about an active torrent
type TorrentInfo struct {
	InfoHash      string    `json:"info_hash"`
	Name          string    `json:"name"`
	Peers         []Peer    `json:"peers"`
	TotalSeeders  int       `json:"total_seeders"`
	TotalLeechers int       `json:"total_leechers"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// Peer represents a connected peer
type Peer struct {
	IP       string    `json:"ip"`
	Port     int       `json:"port"`
	NodeID   string    `json:"node_id"`
	LastSeen time.Time `json:"last_seen"`
}

// AnnounceRequest is sent by peers to announce their presence
type AnnounceRequest struct {
	InfoHash   string `json:"info_hash"`
	PeerID     string `json:"peer_id"`
	Port       int    `json:"port"`
	Uploaded   int64  `json:"uploaded"`
	Downloaded int64  `json:"downloaded"`
	Left       int64  `json:"left"`
	Event      string `json:"event"` // started, stopped, completed
}

// AnnounceResponse is returned to announcing peers
type AnnounceResponse struct {
	Interval int    `json:"interval"`
	Peers    []Peer `json:"peers"`
}

// Config holds DHT node configuration
type Config struct {
	Port               int
	NodeID             string
	BootstrapURL       string
	AnnounceInterval   time.Duration
	MaxPeersPerTorrent int
}

// Node represents a DHT bootstrap/tracker node
type Node struct {
	cfg      Config
	logger   *slog.Logger
	mu       sync.RWMutex
	torrents map[string]*TorrentInfo // info_hash -> info
	peers    map[string]*Peer        // peer_id -> peer
	ctx      context.Context
	cancel   context.CancelFunc
}

// NewNode creates a new DHT bootstrap node
func NewNode(cfg Config, logger *slog.Logger) *Node {
	if cfg.AnnounceInterval == 0 {
		cfg.AnnounceInterval = 30 * time.Second
	}
	if cfg.MaxPeersPerTorrent == 0 {
		cfg.MaxPeersPerTorrent = 200
	}
	if cfg.NodeID == "" {
		cfg.NodeID = generateNodeID()
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &Node{
		cfg:      cfg,
		logger:   logger,
		torrents: make(map[string]*TorrentInfo),
		peers:    make(map[string]*Peer),
		ctx:      ctx,
		cancel:   cancel,
	}
}

// Start begins the DHT node operations
func (n *Node) Start() error {
	n.logger.Info("starting DHT bootstrap node",
		"port", n.cfg.Port,
		"node_id", n.cfg.NodeID,
	)

	// Start cleanup goroutine
	go n.cleanupLoop()

	return nil
}

// Stop gracefully shuts down the DHT node
func (n *Node) Stop() {
	n.logger.Info("stopping DHT bootstrap node")
	n.cancel()
}

// HandleAnnounce processes a peer announce request
func (n *Node) HandleAnnounce(req *AnnounceRequest) AnnounceResponse {
	n.mu.Lock()
	defer n.mu.Unlock()

	// Register the peer
	peer := &Peer{
		Port:     req.Port,
		NodeID:   req.PeerID,
		LastSeen: time.Now(),
	}
	n.peers[req.PeerID] = peer

	// Get or create torrent info
	info, exists := n.torrents[req.InfoHash]
	if !exists {
		info = &TorrentInfo{
			InfoHash:  req.InfoHash,
			Peers:     []Peer{},
			UpdatedAt: time.Now(),
		}
		n.torrents[req.InfoHash] = info
	}

	// Add peer to torrent if not already present
	peerExists := false
	for _, p := range info.Peers {
		if p.NodeID == req.PeerID {
			peerExists = true
			break
		}
	}
	if !peerExists && len(info.Peers) < n.cfg.MaxPeersPerTorrent {
		info.Peers = append(info.Peers, *peer)
	}

	// Update stats
	info.TotalSeeders = len(info.Peers)
	info.UpdatedAt = time.Now()

	n.logger.Debug("peer announced",
		"info_hash", req.InfoHash,
		"peer_id", req.PeerID,
		"event", req.Event,
		"total_peers", len(info.Peers),
	)

	// Return peers (excluding the requesting peer)
	peers := make([]Peer, 0, len(info.Peers))
	for _, p := range info.Peers {
		if p.NodeID != req.PeerID {
			peers = append(peers, p)
		}
	}

	return AnnounceResponse{
		Interval: int(n.cfg.AnnounceInterval.Seconds()),
		Peers:    peers,
	}
}

// GetTorrentInfo returns metadata about a torrent
func (n *Node) GetTorrentInfo(infoHash string) (*TorrentInfo, bool) {
	n.mu.RLock()
	defer n.mu.RUnlock()

	info, exists := n.torrents[infoHash]
	return info, exists
}

// GetActiveTorrents returns all tracked torrents
func (n *Node) GetActiveTorrents() []TorrentInfo {
	n.mu.RLock()
	defer n.mu.RUnlock()

	results := make([]TorrentInfo, 0, len(n.torrents))
	for _, info := range n.torrents {
		results = append(results, *info)
	}
	return results
}

// GetNodeID returns the node's ID
func (n *Node) GetNodeID() string {
	return n.cfg.NodeID
}

// Stats returns current node statistics
type Stats struct {
	NodeID        string `json:"node_id"`
	TotalTorrents int    `json:"total_torrents"`
	TotalPeers    int    `json:"total_peers"`
	Uptime        string `json:"uptime"`
}

func (n *Node) Stats() Stats {
	n.mu.RLock()
	defer n.mu.RUnlock()

	return Stats{
		NodeID:        n.cfg.NodeID,
		TotalTorrents: len(n.torrents),
		TotalPeers:    len(n.peers),
	}
}

// cleanupLoop periodically removes stale peers and torrents
func (n *Node) cleanupLoop() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-n.ctx.Done():
			return
		case <-ticker.C:
			n.cleanup()
		}
	}
}

func (n *Node) cleanup() {
	n.mu.Lock()
	defer n.mu.Unlock()

	now := time.Now()
	staleThreshold := 5 * time.Minute

	// Remove stale peers
	for id, peer := range n.peers {
		if now.Sub(peer.LastSeen) > staleThreshold {
			delete(n.peers, id)
		}
	}

	// Remove stale torrents (no peers for > 10 minutes)
	for hash, info := range n.torrents {
		if now.Sub(info.UpdatedAt) > 10*time.Minute {
			delete(n.torrents, hash)
		}
	}

	n.logger.Debug("DHT cleanup completed",
		"torrents", len(n.torrents),
		"peers", len(n.peers),
	)
}

// generateNodeID creates a random 20-byte node ID
func generateNodeID() string {
	b := make([]byte, 20)
	for i := range b {
		b[i] = byte(time.Now().UnixNano() & 0xFF)
	}
	return hex.EncodeToString(b)
}

// ValidateInfoHash checks if a string is a valid 40-char hex info hash
func ValidateInfoHash(hash string) bool {
	if len(hash) != 40 {
		return false
	}
	_, err := hex.DecodeString(hash)
	return err == nil
}

// InfoHashToBytes converts a hex info hash to bytes
func InfoHashToBytes(hash string) ([]byte, error) {
	return hex.DecodeString(hash)
}
