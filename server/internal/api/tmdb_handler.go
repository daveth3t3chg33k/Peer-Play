package api

import (
	"context"
	"encoding/json"
	"fmt"
	
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/peerplay/server/internal/models"
	"github.com/peerplay/server/internal/tmdb"
)

// handleSyncMovies fetches movies from TMDB and inserts new ones into the database.
// POST /api/v1/movies/sync
// Body: { "categories": ["popular", "action", ...], "pages_per_category": 1 }
// If categories is empty, syncs all known categories.
func (r *Router) handleSyncMovies(w http.ResponseWriter, req *http.Request) {
	if !r.tmdbClient.IsConfigured() {
		respondError(w, http.StatusBadRequest, "TMDB API key not configured — set TMDB_API_KEY environment variable")
		return
	}

	var input struct {
		Categories       []string `json:"categories"`
		PagesPerCategory int      `json:"pages_per_category"`
	}
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if input.PagesPerCategory < 1 || input.PagesPerCategory > 5 {
		input.PagesPerCategory = 2
	}

	// Default to all categories if none specified
	if len(input.Categories) == 0 {
		for cat := range tmdb.CategoryEndpoint {
			input.Categories = append(input.Categories, cat)
		}
	}

	syncID := uuid.New().String()[:8]
	r.logger.Info("TMDB sync started",
		"sync_id", syncID,
		"categories", len(input.Categories),
		"pages_per_category", input.PagesPerCategory,
	)

	// Run sync in background and return immediately
	go r.runSync(context.Background(), syncID, input.Categories, input.PagesPerCategory)

	respondJSON(w, http.StatusAccepted, map[string]interface{}{
		"sync_id":  syncID,
		"status":   "started",
		"message":  fmt.Sprintf("Syncing %d categories, %d pages each", len(input.Categories), input.PagesPerCategory),
	})
}

// handleGetSyncStatus returns the latest sync result (placeholder — we track in-memory).
var latestSyncResult = struct {
	sync.RWMutex
	LastSyncID    string
	TotalFetched  int
	TotalInserted int
	TotalSkipped  int
	TotalFailed   int
	Duration      string
	FinishedAt    string
}{}

func (r *Router) handleGetSyncStatus(w http.ResponseWriter, req *http.Request) {
	latestSyncResult.RLock()
	defer latestSyncResult.RUnlock()

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"last_sync_id":     latestSyncResult.LastSyncID,
		"total_fetched":    latestSyncResult.TotalFetched,
		"total_inserted":   latestSyncResult.TotalInserted,
		"total_skipped":    latestSyncResult.TotalSkipped,
		"total_failed":     latestSyncResult.TotalFailed,
		"duration":         latestSyncResult.Duration,
		"finished_at":      latestSyncResult.FinishedAt,
	})
}

func (r *Router) runSync(ctx context.Context, syncID string, categories []string, pagesPerCategory int) {
	start := time.Now()
	var (
		mu            sync.Mutex
		totalFetched  int
		totalInserted int
		totalSkipped  int
		totalFailed   int
	)

	for _, cat := range categories {
		movies, err := r.tmdbClient.FetchMovies(cat, pagesPerCategory)
		if err != nil {
			r.logger.Error("TMDB fetch failed",
				"sync_id", syncID,
				"category", cat,
				"error", err,
			)
			mu.Lock()
			totalFailed++
			mu.Unlock()
			continue
		}

		r.logger.Info("TMDB fetch complete",
			"sync_id", syncID,
			"category", cat,
			"fetched", len(movies),
		)

		for _, m := range movies {
			// Deduplicate by title
			exists, err := r.movieRepo.ExistsByTitle(ctx, m.Title)
			if err != nil {
				r.logger.Warn("dedup check failed", "title", m.Title, "error", err)
				continue
			}
			if exists {
				mu.Lock()
				totalSkipped++
				mu.Unlock()
				continue
			}

			movie := &models.Movie{
				ID:                uuid.New(),
				Title:             m.Title,
				Description:       m.Description,
				ReleaseYear:       m.ReleaseYear,
				Genres:            m.Genres,
				PosterURL:         m.PosterURL,
				BackdropURL:       m.BackdropURL,
				DurationMinutes:   m.DurationMinutes,
				Rating:            m.Rating,
				Category:          m.Category,
				YoutubeTrailerKey: m.YoutubeTrailerKey,
			}

			if err := r.movieRepo.Create(ctx, movie); err != nil {
				r.logger.Warn("insert failed", "title", m.Title, "error", err)
				mu.Lock()
				totalFailed++
				mu.Unlock()
				continue
			}

			mu.Lock()
			totalInserted++
			mu.Unlock()
		}

		mu.Lock()
		totalFetched += len(movies)
		mu.Unlock()
	}

	duration := time.Since(start)
	finishedAt := time.Now().Format(time.RFC3339)

	latestSyncResult.Lock()
	latestSyncResult.LastSyncID = syncID
	latestSyncResult.TotalFetched = totalFetched
	latestSyncResult.TotalInserted = totalInserted
	latestSyncResult.TotalSkipped = totalSkipped
	latestSyncResult.TotalFailed = totalFailed
	latestSyncResult.Duration = duration.Round(time.Millisecond).String()
	latestSyncResult.FinishedAt = finishedAt
	latestSyncResult.Unlock()

	r.logger.Info("TMDB sync complete",
		"sync_id", syncID,
		"fetched", totalFetched,
		"inserted", totalInserted,
		"skipped", totalSkipped,
		"failed", totalFailed,
		"duration", duration.Round(time.Millisecond).String(),
	)
}
