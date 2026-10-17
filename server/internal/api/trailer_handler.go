package api

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
)

// handleUpdateTrailerKeys fetches YouTube trailer keys from TMDB for all movies
// that currently have an empty youtube_trailer_key.
// POST /api/v1/movies/update-trailer-keys
func (r *Router) handleUpdateTrailerKeys(w http.ResponseWriter, req *http.Request) {
	if !r.tmdbClient.IsConfigured() {
		respondError(w, http.StatusBadRequest, "TMDB API key not configured — set TMDB_API_KEY environment variable")
		return
	}

	movies, err := r.movieRepo.GetWithoutTrailerKey(req.Context())
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to fetch movies")
		return
	}

	if len(movies) == 0 {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":  "nothing_to_do",
			"message": "All movies already have trailer keys",
		})
		return
	}

	r.logger.Info("Trailer key update started", "total_movies", len(movies))

	// Convert to update list
	toUpdate := make([]movieToUpdate, len(movies))
	for i, m := range movies {
		toUpdate[i] = movieToUpdate{ID: m.ID, Title: m.Title}
	}

	go r.runTrailerKeyUpdate(context.Background(), toUpdate)

	respondJSON(w, http.StatusAccepted, map[string]interface{}{
		"status":       "started",
		"total_movies": len(movies),
		"message":      fmt.Sprintf("Updating trailer keys for %d movies in background", len(movies)),
	})
}

// handleGetTrailerUpdateStatus returns the latest trailer key update result.
func (r *Router) handleGetTrailerUpdateStatus(w http.ResponseWriter, req *http.Request) {
	trailerUpdateResult.RLock()
	defer trailerUpdateResult.RUnlock()

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"updated":      trailerUpdateResult.Updated,
		"not_found":    trailerUpdateResult.NotFound,
		"failed":       trailerUpdateResult.Failed,
		"total_movies": trailerUpdateResult.TotalMovies,
		"duration":     trailerUpdateResult.Duration,
		"finished_at":  trailerUpdateResult.FinishedAt,
	})
}

var trailerUpdateResult = struct {
	sync.RWMutex
	Updated     int64
	NotFound    int64
	Failed      int64
	TotalMovies int
	Duration    string
	FinishedAt  string
}{}

type movieToUpdate struct {
	ID    uuid.UUID
	Title string
}

func (r *Router) runTrailerKeyUpdate(ctx context.Context, movies []movieToUpdate) {
	start := time.Now()
	var updated, notFound, failed int64

	sem := make(chan struct{}, 5)
	var wg sync.WaitGroup

	for _, m := range movies {
		wg.Add(1)
		sem <- struct{}{}

		go func(m movieToUpdate) {
			defer wg.Done()
			defer func() { <-sem }()

			tmdbID := r.tmdbClient.SearchMovieByName(m.Title)
			if tmdbID == 0 {
				r.logger.Debug("Movie not found on TMDB", "title", m.Title)
				atomic.AddInt64(&notFound, 1)
				return
			}

			key := r.tmdbClient.FetchTrailerKey(tmdbID)
			if key == "" {
				r.logger.Debug("No trailer found", "title", m.Title, "tmdb_id", tmdbID)
				atomic.AddInt64(&notFound, 1)
				return
			}

			if err := r.movieRepo.UpdateTrailerKey(ctx, m.ID, key); err != nil {
				r.logger.Warn("Failed to update trailer key", "title", m.Title, "error", err)
				atomic.AddInt64(&failed, 1)
				return
			}

			atomic.AddInt64(&updated, 1)
			r.logger.Debug("Updated trailer key", "title", m.Title, "key", key)
		}(m)
	}

	wg.Wait()
	duration := time.Since(start)

	trailerUpdateResult.Lock()
	trailerUpdateResult.Updated = updated
	trailerUpdateResult.NotFound = notFound
	trailerUpdateResult.Failed = failed
	trailerUpdateResult.TotalMovies = len(movies)
	trailerUpdateResult.Duration = duration.Round(time.Millisecond).String()
	trailerUpdateResult.FinishedAt = time.Now().Format(time.RFC3339)
	trailerUpdateResult.Unlock()

	r.logger.Info("Trailer key update complete",
		"updated", updated,
		"not_found", notFound,
		"failed", failed,
		"duration", duration.Round(time.Millisecond).String(),
	)
}
