package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/peerplay/server/internal/models"
)

// MovieRepository defines the interface for movie data access
type MovieRepository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*models.Movie, error)
	List(ctx context.Context, page, pageSize int) ([]models.Movie, int, error)
	Search(ctx context.Context, query models.MovieSearchQuery) ([]models.Movie, int, error)
	GetTrending(ctx context.Context, limit int) ([]models.Movie, error)
	GetRecent(ctx context.Context, limit int) ([]models.Movie, error)
	GetByCategory(ctx context.Context, category string, limit int) ([]models.Movie, error)
	GetGenres(ctx context.Context) ([]string, error)
	GetCastByMovieID(ctx context.Context, movieID uuid.UUID) ([]models.CastMember, error)
	Create(ctx context.Context, movie *models.Movie) error
	Update(ctx context.Context, movie *models.Movie) error
	Delete(ctx context.Context, id uuid.UUID) error
}

// movieRepository is the Postgres implementation of MovieRepository
type movieRepository struct {
	db *DB
}

// NewMovieRepository creates a new movie repository
func NewMovieRepository(db *DB) MovieRepository {
	return &movieRepository{db: db}
}

func (r *movieRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Movie, error) {
	var movie models.Movie

	query := `
		SELECT id, title, description, release_year, genres, poster_url, backdrop_url,
		       duration_minutes, rating, info_hash, category, created_at, updated_at
		FROM movies
		WHERE id = $1`

	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&movie.ID, &movie.Title, &movie.Description, &movie.ReleaseYear,
		&movie.Genres, &movie.PosterURL, &movie.BackdropURL,
		&movie.DurationMinutes, &movie.Rating, &movie.InfoHash,
		&movie.Category, &movie.CreatedAt, &movie.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("movie not found")
		}
		return nil, fmt.Errorf("failed to get movie: %w", err)
	}

	// Fetch sources
	sourcesQuery := `
		SELECT id, movie_id, quality, magnet_link, file_size_bytes, codec, created_at
		FROM video_sources WHERE movie_id = $1`
	rows, err := r.db.Pool.Query(ctx, sourcesQuery, id)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var src models.VideoSource
			if err := rows.Scan(&src.ID, &src.MovieID, &src.Quality, &src.MagnetLink,
				&src.FileSizeByte, &src.Codec, &src.CreatedAt); err == nil {
				movie.Sources = append(movie.Sources, src)
			}
		}
	}

	// Fetch subtitles
	subQuery := `
		SELECT id, movie_id, language_code, language_name, file_url, format, created_at
		FROM subtitles WHERE movie_id = $1`
	subRows, err := r.db.Pool.Query(ctx, subQuery, id)
	if err == nil {
		defer subRows.Close()
		for subRows.Next() {
			var sub models.Subtitle
			if err := subRows.Scan(&sub.ID, &sub.MovieID, &sub.LanguageCode, &sub.LanguageName,
				&sub.FileURL, &sub.Format, &sub.CreatedAt); err == nil {
				movie.Subtitles = append(movie.Subtitles, sub)
			}
		}
	}

	return &movie, nil
}

func (r *movieRepository) List(ctx context.Context, page, pageSize int) ([]models.Movie, int, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	// Count total
	var total int
	err := r.db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM movies").Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count movies: %w", err)
	}

	// Fetch page
	query := `
		SELECT id, title, description, release_year, genres, poster_url, backdrop_url,
		       duration_minutes, rating, info_hash, category, created_at, updated_at
		FROM movies
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2`

	rows, err := r.db.Pool.Query(ctx, query, pageSize, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list movies: %w", err)
	}
	defer rows.Close()

	movies, err := scanMovies(rows)
	if err != nil {
		return nil, 0, err
	}

	return movies, total, nil
}

func (r *movieRepository) Search(ctx context.Context, q models.MovieSearchQuery) ([]models.Movie, int, error) {
	if q.Page < 1 {
		q.Page = 1
	}
	if q.PageSize < 1 || q.PageSize > 100 {
		q.PageSize = 20
	}

	var conditions []string
	var args []interface{}
	argIdx := 1

	if q.Query != "" {
		conditions = append(conditions, fmt.Sprintf("to_tsvector('english', title) @@ plainto_tsquery('english', $%d)", argIdx))
		args = append(args, q.Query)
		argIdx++
	}
	if len(q.Genres) > 0 {
		conditions = append(conditions, fmt.Sprintf("genres && $%d", argIdx))
		args = append(args, q.Genres)
		argIdx++
	}
	if q.YearFrom > 0 {
		conditions = append(conditions, fmt.Sprintf("release_year >= $%d", argIdx))
		args = append(args, q.YearFrom)
		argIdx++
	}
	if q.YearTo > 0 {
		conditions = append(conditions, fmt.Sprintf("release_year <= $%d", argIdx))
		args = append(args, q.YearTo)
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	// Count
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM movies %s", whereClause)
	var total int
	err := r.db.Pool.QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count movies: %w", err)
	}

	// Fetch
	offset := (q.Page - 1) * q.PageSize
	dataArgs := make([]interface{}, len(args), len(args)+2)
	copy(dataArgs, args)
	dataArgs = append(dataArgs, q.PageSize, offset)
	dataQuery := fmt.Sprintf(`
		SELECT id, title, description, release_year, genres, poster_url, backdrop_url,
		       duration_minutes, rating, info_hash, category, created_at, updated_at
		FROM movies %s
		ORDER BY ts_rank(to_tsvector('english', title), plainto_tsquery('english', $1)) DESC, created_at DESC
		LIMIT $%d OFFSET $%d`, whereClause, argIdx, argIdx+1)

	rows, err := r.db.Pool.Query(ctx, dataQuery, dataArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to search movies: %w", err)
	}
	defer rows.Close()

	movies, err := scanMovies(rows)
	if err != nil {
		return nil, 0, err
	}

	return movies, total, nil
}

func (r *movieRepository) GetTrending(ctx context.Context, limit int) ([]models.Movie, error) {
	query := `
		SELECT m.id, m.title, m.description, m.release_year, m.genres, m.poster_url,
		       m.backdrop_url, m.duration_minutes, m.rating, m.info_hash, m.category, m.created_at, m.updated_at
		FROM movies m
		ORDER BY m.rating DESC NULLS LAST, m.created_at DESC
		LIMIT $1`

	rows, err := r.db.Pool.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get trending: %w", err)
	}
	defer rows.Close()

	return scanMovies(rows)
}

func (r *movieRepository) GetRecent(ctx context.Context, limit int) ([]models.Movie, error) {
	query := `
		SELECT id, title, description, release_year, genres, poster_url, backdrop_url,
		       duration_minutes, rating, info_hash, category, created_at, updated_at
		FROM movies
		ORDER BY created_at DESC
		LIMIT $1`

	rows, err := r.db.Pool.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get recent: %w", err)
	}
	defer rows.Close()

	return scanMovies(rows)
}

func (r *movieRepository) GetByCategory(ctx context.Context, category string, limit int) ([]models.Movie, error) {
	query := `
		SELECT id, title, description, release_year, genres, poster_url, backdrop_url,
		       duration_minutes, rating, info_hash, category, created_at, updated_at
		FROM movies
		WHERE category = $1
		ORDER BY rating DESC NULLS LAST
		LIMIT $2`

	rows, err := r.db.Pool.Query(ctx, query, category, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get movies by category: %w", err)
	}
	defer rows.Close()

	return scanMovies(rows)
}

func (r *movieRepository) GetGenres(ctx context.Context) ([]string, error) {
	query := `SELECT DISTINCT unnest(genres) FROM movies ORDER BY 1`
	rows, err := r.db.Pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get genres: %w", err)
	}
	defer rows.Close()

	var genres []string
	for rows.Next() {
		var genre string
		if err := rows.Scan(&genre); err != nil {
			return nil, err
		}
		genres = append(genres, genre)
	}
	return genres, rows.Err()
}

func (r *movieRepository) GetCastByMovieID(ctx context.Context, movieID uuid.UUID) ([]models.CastMember, error) {
	query := `
		SELECT id, movie_id, name, character, profile_path, department, sort_order, created_at
		FROM cast_members
		WHERE movie_id = $1
		ORDER BY sort_order ASC`

	rows, err := r.db.Pool.Query(ctx, query, movieID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cast: %w", err)
	}
	defer rows.Close()

	var members []models.CastMember
	for rows.Next() {
		var m models.CastMember
		if err := rows.Scan(&m.ID, &m.MovieID, &m.Name, &m.Character,
			&m.ProfilePath, &m.Department, &m.Order, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan cast member: %w", err)
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

func (r *movieRepository) Create(ctx context.Context, movie *models.Movie) error {
	query := `
		INSERT INTO movies (id, title, description, release_year, genres, poster_url, backdrop_url,
		                     duration_minutes, rating, info_hash)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING created_at, updated_at`

	return r.db.Pool.QueryRow(ctx, query,
		movie.ID, movie.Title, movie.Description, movie.ReleaseYear,
		movie.Genres, movie.PosterURL, movie.BackdropURL,
		movie.DurationMinutes, movie.Rating, movie.InfoHash,
	).Scan(&movie.CreatedAt, &movie.UpdatedAt)
}

func (r *movieRepository) Update(ctx context.Context, movie *models.Movie) error {
	query := `
		UPDATE movies
		SET title = $2, description = $3, release_year = $4, genres = $5,
		    poster_url = $6, backdrop_url = $7, duration_minutes = $8,
		    rating = $9, info_hash = $10, updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at`

	return r.db.Pool.QueryRow(ctx, query,
		movie.ID, movie.Title, movie.Description, movie.ReleaseYear,
		movie.Genres, movie.PosterURL, movie.BackdropURL,
		movie.DurationMinutes, movie.Rating, movie.InfoHash,
	).Scan(&movie.UpdatedAt)
}

func (r *movieRepository) Delete(ctx context.Context, id uuid.UUID) error {
	result, err := r.db.Pool.Exec(ctx, "DELETE FROM movies WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("failed to delete movie: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("movie not found")
	}
	return nil
}

// scanMovies helper scans pgx.Rows into a slice of movies
func scanMovies(rows pgx.Rows) ([]models.Movie, error) {
	defer rows.Close()

	var movies []models.Movie
	for rows.Next() {
		var movie models.Movie
		if err := rows.Scan(
			&movie.ID, &movie.Title, &movie.Description, &movie.ReleaseYear,
			&movie.Genres, &movie.PosterURL, &movie.BackdropURL,
			&movie.DurationMinutes, &movie.Rating, &movie.InfoHash,
			&movie.Category, &movie.CreatedAt, &movie.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan movie: %w", err)
		}
		movies = append(movies, movie)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("row iteration error: %w", err)
	}

	return movies, nil
}
