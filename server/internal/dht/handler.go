package dht

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// Handler exposes DHT node operations via HTTP
type Handler struct {
	node *Node
}

// NewHandler creates a new DHT HTTP handler
func NewHandler(node *Node) *Handler {
	return &Handler{node: node}
}

// Routes returns a chi.Router with DHT endpoints
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/stats", h.handleStats)
	r.Get("/torrents", h.handleListTorrents)
	r.Get("/torrents/{info_hash}", h.handleGetTorrent)
	r.Post("/announce", h.handleAnnounce)

	return r
}

func (h *Handler) handleStats(w http.ResponseWriter, r *http.Request) {
	stats := h.node.Stats()
	respondJSON(w, http.StatusOK, stats)
}

func (h *Handler) handleListTorrents(w http.ResponseWriter, r *http.Request) {
	torrents := h.node.GetActiveTorrents()
	respondJSON(w, http.StatusOK, torrents)
}

func (h *Handler) handleGetTorrent(w http.ResponseWriter, r *http.Request) {
	infoHash := chi.URLParam(r, "info_hash")

	if !ValidateInfoHash(infoHash) {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid info_hash format"})
		return
	}

	info, exists := h.node.GetTorrentInfo(infoHash)
	if !exists {
		respondJSON(w, http.StatusNotFound, map[string]string{"error": "torrent not found"})
		return
	}

	respondJSON(w, http.StatusOK, info)
}

func (h *Handler) handleAnnounce(w http.ResponseWriter, r *http.Request) {
	var req AnnounceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	if !ValidateInfoHash(req.InfoHash) {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid info_hash format"})
		return
	}

	if req.PeerID == "" {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "peer_id is required"})
		return
	}

	resp := h.node.HandleAnnounce(&req)
	respondJSON(w, http.StatusOK, resp)
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
