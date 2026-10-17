package models

import (
	"time"

	"github.com/google/uuid"
)

// Movie represents a movie in the catalog
type Movie struct {
	ID              uuid.UUID     `json:"id" db:"id"`
	Title           string        `json:"title" db:"title"`
	Description     string        `json:"description" db:"description"`
	ReleaseYear     int           `json:"release_year" db:"release_year"`
	Genres          []string      `json:"genres" db:"genres"`
	PosterURL       string        `json:"poster_url" db:"poster_url"`
	BackdropURL     string        `json:"backdrop_url" db:"backdrop_url"`
	DurationMinutes int           `json:"duration_minutes" db:"duration_minutes"`
	Rating          float64       `json:"rating" db:"rating"`
	InfoHash          string        `json:"info_hash,omitempty" db:"info_hash"`
	Category          string        `json:"category" db:"category"`
	YoutubeTrailerKey string        `json:"youtube_trailer_key,omitempty" db:"youtube_trailer_key"`
	CreatedAt       time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time     `json:"updated_at" db:"updated_at"`
	Sources         []VideoSource `json:"sources,omitempty"`
	Subtitles       []Subtitle    `json:"subtitles,omitempty"`
}

// VideoSource represents a torrent/magnet source for a movie
type VideoSource struct {
	ID           uuid.UUID `json:"id" db:"id"`
	MovieID      uuid.UUID `json:"movie_id" db:"movie_id"`
	Quality      string    `json:"quality" db:"quality"`
	MagnetLink   string    `json:"magnet_link,omitempty" db:"magnet_link"`
	FileSizeByte int64     `json:"file_size_bytes" db:"file_size_bytes"`
	Codec        string    `json:"codec" db:"codec"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// Subtitle represents a subtitle file for a movie
type Subtitle struct {
	ID           uuid.UUID `json:"id" db:"id"`
	MovieID      uuid.UUID `json:"movie_id" db:"movie_id"`
	LanguageCode string    `json:"language_code" db:"language_code"`
	LanguageName string    `json:"language_name" db:"language_name"`
	FileURL      string    `json:"file_url" db:"file_url"`
	Format       string    `json:"format" db:"format"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// User represents an application user
type User struct {
	ID                uuid.UUID `json:"id" db:"id"`
	Email             string    `json:"email" db:"email"`
	PasswordHash      string    `json:"-" db:"password_hash"`
	DisplayName       string    `json:"display_name" db:"display_name"`
	DeviceFingerprint string    `json:"device_fingerprint,omitempty" db:"device_fingerprint"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

// WatchHistory tracks user watch progress
type WatchHistory struct {
	ID              uuid.UUID `json:"id" db:"id"`
	UserID          uuid.UUID `json:"user_id" db:"user_id"`
	MovieID         uuid.UUID `json:"movie_id" db:"movie_id"`
	ProgressSeconds int       `json:"progress_seconds" db:"progress_seconds"`
	Completed       bool      `json:"completed" db:"completed"`
	LastWatchedAt   time.Time `json:"last_watched_at" db:"last_watched_at"`
	Movie           *Movie    `json:"movie,omitempty"`
}

// Bookmark represents a user's bookmarked movie
type Bookmark struct {
	ID        uuid.UUID `json:"id" db:"id"`
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	MovieID   uuid.UUID `json:"movie_id" db:"movie_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	Movie     *Movie    `json:"movie,omitempty"`
}

// CastMember represents an actor/crew member for a movie
type CastMember struct {
	ID           uuid.UUID `json:"id" db:"id"`
	MovieID      uuid.UUID `json:"movie_id" db:"movie_id"`
	Name         string    `json:"name" db:"name"`
	Character    string    `json:"character" db:"character"`
	ProfilePath  string    `json:"profile_path" db:"profile_path"`
	Department   string    `json:"department" db:"department"`
	Order        int       `json:"order" db:"order"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// Pagination holds pagination parameters
type Pagination struct {
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
	Total    int `json:"total"`
}

// PaginatedResponse wraps a list response with pagination info
type PaginatedResponse struct {
	Data       interface{} `json:"data"`
	Pagination Pagination  `json:"pagination"`
}

// --- Request/Response DTOs ---

// RegisterRequest is the DTO for user registration
type RegisterRequest struct {
	Email             string `json:"email"`
	Password          string `json:"password"`
	DisplayName       string `json:"display_name"`
	DeviceFingerprint string `json:"device_fingerprint"`
}

// LoginRequest is the DTO for user login
type LoginRequest struct {
	Email             string `json:"email"`
	Password          string `json:"password"`
	DeviceFingerprint string `json:"device_fingerprint"`
}

// AuthResponse is the DTO returned after successful auth
type AuthResponse struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expires_at"`
	User      User   `json:"user"`
}

// MovieSearchQuery holds search/filter parameters
type MovieSearchQuery struct {
	Query    string   `form:"q"`
	Genres   []string `form:"genres"`
	YearFrom int      `form:"year_from"`
	YearTo   int      `form:"year_to"`
	Page     int      `form:"page"`
	PageSize int      `form:"page_size"`
}

// HealthResponse is the DTO for health check
type HealthResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
	Uptime  string `json:"uptime"`
}
