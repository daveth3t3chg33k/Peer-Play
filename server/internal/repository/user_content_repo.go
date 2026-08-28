package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/peerplay/server/internal/models"
)

// UserContentRepository defines the interface for user content data access
type UserContentRepository interface {
	// Watch History
	GetWatchHistory(ctx context.Context, userID uuid.UUID, page, pageSize int) ([]models.WatchHistory, int, error)
	UpdateWatchProgress(ctx context.Context, userID, movieID uuid.UUID, progressSeconds int, completed bool) error
	DeleteWatchHistory(ctx context.Context, userID, movieID uuid.UUID) error

	// Bookmarks
	GetBookmarks(ctx context.Context, userID uuid.UUID, page, pageSize int) ([]models.Bookmark, int, error)
	AddBookmark(ctx context.Context, userID, movieID uuid.UUID) error
	RemoveBookmark(ctx context.Context, userID, movieID uuid.UUID) error
	IsBookmarked(ctx context.Context, userID, movieID uuid.UUID) (bool, error)
}

type userContentRepository struct {
	db *DB
}

// NewUserContentRepository creates a new user content repository
func NewUserContentRepository(db *DB) UserContentRepository {
	return &userContentRepository{db: db}
}

// --- Watch History ---

func (r *userContentRepository) GetWatchHistory(ctx context.Context, userID uuid.UUID, page, pageSize int) ([]models.WatchHistory, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	// Count total
	var total int
	err := r.db.Pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM watch_history WHERE user_id = $1", userID,
	).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count watch history: %w", err)
	}

	// Fetch with joined movie data
	query := `
		SELECT wh.id, wh.user_id, wh.movie_id, wh.progress_seconds, wh.completed, wh.last_watched_at,
		       m.id, m.title, m.description, m.release_year, m.genres, m.poster_url, m.backdrop_url,
		       m.duration_minutes, m.rating, m.info_hash, m.created_at, m.updated_at
		FROM watch_history wh
		JOIN movies m ON m.id = wh.movie_id
		WHERE wh.user_id = $1
		ORDER BY wh.last_watched_at DESC
		LIMIT $2 OFFSET $3`

	rows, err := r.db.Pool.Query(ctx, query, userID, pageSize, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get watch history: %w", err)
	}
	defer rows.Close()

	var history []models.WatchHistory
	for rows.Next() {
		var wh models.WatchHistory
		var movie models.Movie
		if err := rows.Scan(
			&wh.ID, &wh.UserID, &wh.MovieID, &wh.ProgressSeconds, &wh.Completed, &wh.LastWatchedAt,
			&movie.ID, &movie.Title, &movie.Description, &movie.ReleaseYear, &movie.Genres,
			&movie.PosterURL, &movie.BackdropURL, &movie.DurationMinutes, &movie.Rating,
			&movie.InfoHash, &movie.CreatedAt, &movie.UpdatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("failed to scan watch history: %w", err)
		}
		wh.Movie = &movie
		history = append(history, wh)
	}

	return history, total, nil
}

func (r *userContentRepository) UpdateWatchProgress(ctx context.Context, userID, movieID uuid.UUID, progressSeconds int, completed bool) error {
	query := `
		INSERT INTO watch_history (user_id, movie_id, progress_seconds, completed, last_watched_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id, movie_id)
		DO UPDATE SET progress_seconds = $3, completed = $4, last_watched_at = NOW()`

	_, err := r.db.Pool.Exec(ctx, query, userID, movieID, progressSeconds, completed)
	if err != nil {
		return fmt.Errorf("failed to update watch progress: %w", err)
	}
	return nil
}

func (r *userContentRepository) DeleteWatchHistory(ctx context.Context, userID, movieID uuid.UUID) error {
	result, err := r.db.Pool.Exec(ctx,
		"DELETE FROM watch_history WHERE user_id = $1 AND movie_id = $2", userID, movieID,
	)
	if err != nil {
		return fmt.Errorf("failed to delete watch history: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("watch history entry not found")
	}
	return nil
}

// --- Bookmarks ---

func (r *userContentRepository) GetBookmarks(ctx context.Context, userID uuid.UUID, page, pageSize int) ([]models.Bookmark, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	// Count total
	var total int
	err := r.db.Pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM bookmarks WHERE user_id = $1", userID,
	).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count bookmarks: %w", err)
	}

	// Fetch with joined movie data
	query := `
		SELECT b.id, b.user_id, b.movie_id, b.created_at,
		       m.id, m.title, m.description, m.release_year, m.genres, m.poster_url, m.backdrop_url,
		       m.duration_minutes, m.rating, m.info_hash, m.created_at, m.updated_at
		FROM bookmarks b
		JOIN movies m ON m.id = b.movie_id
		WHERE b.user_id = $1
		ORDER BY b.created_at DESC
		LIMIT $2 OFFSET $3`

	rows, err := r.db.Pool.Query(ctx, query, userID, pageSize, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get bookmarks: %w", err)
	}
	defer rows.Close()

	var bookmarks []models.Bookmark
	for rows.Next() {
		var bm models.Bookmark
		var movie models.Movie
		if err := rows.Scan(
			&bm.ID, &bm.UserID, &bm.MovieID, &bm.CreatedAt,
			&movie.ID, &movie.Title, &movie.Description, &movie.ReleaseYear, &movie.Genres,
			&movie.PosterURL, &movie.BackdropURL, &movie.DurationMinutes, &movie.Rating,
			&movie.InfoHash, &movie.CreatedAt, &movie.UpdatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("failed to scan bookmark: %w", err)
		}
		bm.Movie = &movie
		bookmarks = append(bookmarks, bm)
	}

	return bookmarks, total, nil
}

func (r *userContentRepository) AddBookmark(ctx context.Context, userID, movieID uuid.UUID) error {
	query := `
		INSERT INTO bookmarks (id, user_id, movie_id)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, movie_id) DO NOTHING`

	_, err := r.db.Pool.Exec(ctx, query, uuid.New(), userID, movieID)
	if err != nil {
		return fmt.Errorf("failed to add bookmark: %w", err)
	}
	return nil
}

func (r *userContentRepository) RemoveBookmark(ctx context.Context, userID, movieID uuid.UUID) error {
	result, err := r.db.Pool.Exec(ctx,
		"DELETE FROM bookmarks WHERE user_id = $1 AND movie_id = $2", userID, movieID,
	)
	if err != nil {
		return fmt.Errorf("failed to remove bookmark: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("bookmark not found")
	}
	return nil
}

func (r *userContentRepository) IsBookmarked(ctx context.Context, userID, movieID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM bookmarks WHERE user_id = $1 AND movie_id = $2)", userID, movieID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check bookmark: %w", err)
	}
	return exists, nil
}
