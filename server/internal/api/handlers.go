package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/peerplay/server/internal/middleware"
	"github.com/peerplay/server/internal/models"
)

// --- Health ---

func (r *Router) handleHealth(w http.ResponseWriter, req *http.Request) {
	respondJSON(w, http.StatusOK, models.HealthResponse{
		Status:  "ok",
		Version: "1.0.0",
		Uptime:  time.Since(r.startTime).Round(time.Second).String(),
	})
}

// --- Auth ---

func (r *Router) handleRegister(w http.ResponseWriter, req *http.Request) {
	var input models.RegisterRequest
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if input.Email == "" || input.Password == "" {
		respondError(w, http.StatusBadRequest, "email and password are required")
		return
	}

	// Check if user already exists
	_, err := r.userRepo.GetByEmail(req.Context(), input.Email)
	if err == nil {
		respondError(w, http.StatusConflict, "user with this email already exists")
		return
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to hash password")
		return
	}

	user := &models.User{
		ID:                uuid.New(),
		Email:             input.Email,
		PasswordHash:      string(hash),
		DisplayName:       input.DisplayName,
		DeviceFingerprint: input.DeviceFingerprint,
	}

	if err := r.userRepo.Create(req.Context(), user); err != nil {
		respondError(w, http.StatusInternalServerError, "failed to create user")
		return
	}

	// Generate JWT
	token, expiresAt, err := r.generateToken(user, input.DeviceFingerprint)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	respondJSON(w, http.StatusCreated, models.AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
	})
}

func (r *Router) handleLogin(w http.ResponseWriter, req *http.Request) {
	var input models.LoginRequest
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if input.Email == "" || input.Password == "" {
		respondError(w, http.StatusBadRequest, "email and password are required")
		return
	}

	user, err := r.userRepo.GetByEmail(req.Context(), input.Email)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		respondError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	token, expiresAt, err := r.generateToken(user, input.DeviceFingerprint)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	respondJSON(w, http.StatusOK, models.AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
	})
}

func (r *Router) generateToken(user *models.User, deviceFP string) (string, int64, error) {
	exp := time.Now().Add(time.Duration(r.cfg.JWT.ExpirationHours) * time.Hour)

	claims := &middleware.Claims{
		UserID:            user.ID.String(),
		Email:             user.Email,
		DeviceFingerprint: deviceFP,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(exp),
			Issuer:    r.cfg.JWT.Issuer,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(r.cfg.JWT.Secret))
	if err != nil {
		return "", 0, err
	}

	return tokenString, exp.Unix(), nil
}

// --- Movies ---

func (r *Router) handleListMovies(w http.ResponseWriter, req *http.Request) {
	page, _ := strconv.Atoi(req.URL.Query().Get("page"))
	pageSize, _ := strconv.Atoi(req.URL.Query().Get("page_size"))

	movies, total, err := r.movieRepo.List(req.Context(), page, pageSize)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to list movies")
		return
	}

	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}

	respondJSON(w, http.StatusOK, models.PaginatedResponse{
		Data: movies,
		Pagination: models.Pagination{
			Page:     page,
			PageSize: pageSize,
			Total:    total,
		},
	})
}

func (r *Router) handleGetMovie(w http.ResponseWriter, req *http.Request) {
	idStr := chi.URLParam(req, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	movie, err := r.movieRepo.GetByID(req.Context(), id)
	if err != nil {
		respondError(w, http.StatusNotFound, "movie not found")
		return
	}

	respondJSON(w, http.StatusOK, movie)
}

func (r *Router) handleSearchMovies(w http.ResponseWriter, req *http.Request) {
	yearFrom, _ := strconv.Atoi(req.URL.Query().Get("year_from"))
	yearTo, _ := strconv.Atoi(req.URL.Query().Get("year_to"))
	page, _ := strconv.Atoi(req.URL.Query().Get("page"))
	pageSize, _ := strconv.Atoi(req.URL.Query().Get("page_size"))

	query := models.MovieSearchQuery{
		Query:    req.URL.Query().Get("q"),
		YearFrom: yearFrom,
		YearTo:   yearTo,
		Page:     page,
		PageSize: pageSize,
	}

	// Parse genres
	if genresStr := req.URL.Query().Get("genres"); genresStr != "" {
		query.Genres = append(query.Genres, splitComma(genresStr)...)
	}

	movies, total, err := r.movieRepo.Search(req.Context(), query)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to search movies")
		return
	}

	if query.Page < 1 {
		query.Page = 1
	}
	if query.PageSize < 1 {
		query.PageSize = 20
	}

	respondJSON(w, http.StatusOK, models.PaginatedResponse{
		Data: movies,
		Pagination: models.Pagination{
			Page:     query.Page,
			PageSize: query.PageSize,
			Total:    total,
		},
	})
}

func (r *Router) handleTrendingMovies(w http.ResponseWriter, req *http.Request) {
	limit, _ := strconv.Atoi(req.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 10
	}

	movies, err := r.movieRepo.GetTrending(req.Context(), limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get trending movies")
		return
	}

	respondJSON(w, http.StatusOK, movies)
}

func (r *Router) handleRecentMovies(w http.ResponseWriter, req *http.Request) {
	limit, _ := strconv.Atoi(req.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 10
	}

	movies, err := r.movieRepo.GetRecent(req.Context(), limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get recent movies")
		return
	}

	respondJSON(w, http.StatusOK, movies)
}

func (r *Router) handleMoviesByCategory(w http.ResponseWriter, req *http.Request) {
	category := chi.URLParam(req, "category")
	limit, _ := strconv.Atoi(req.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 20
	}

	movies, err := r.movieRepo.GetByCategory(req.Context(), category, limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get movies by category")
		return
	}

	respondJSON(w, http.StatusOK, movies)
}

func (r *Router) handleGetGenres(w http.ResponseWriter, req *http.Request) {
	genres, err := r.movieRepo.GetGenres(req.Context())
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get genres")
		return
	}

	respondJSON(w, http.StatusOK, genres)
}

func (r *Router) handlePopularMovies(w http.ResponseWriter, req *http.Request) {
	limit, _ := strconv.Atoi(req.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 20
	}
	movies, err := r.movieRepo.GetByCategory(req.Context(), "popular", limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get popular movies")
		return
	}
	respondJSON(w, http.StatusOK, movies)
}

func (r *Router) handleTopRatedMovies(w http.ResponseWriter, req *http.Request) {
	limit, _ := strconv.Atoi(req.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 20
	}
	movies, err := r.movieRepo.GetByCategory(req.Context(), "top_rated", limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get top rated movies")
		return
	}
	respondJSON(w, http.StatusOK, movies)
}

// --- User ---

func (r *Router) handleGetCurrentUser(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	user, err := r.userRepo.GetByID(req.Context(), userID)
	if err != nil {
		respondError(w, http.StatusNotFound, "user not found")
		return
	}

	respondJSON(w, http.StatusOK, user)
}

// --- Vault (placeholder) ---

func (r *Router) handleGetVault(w http.ResponseWriter, req *http.Request) {
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"downloads": []interface{}{},
		"message":   "vault endpoint - implementation pending Phase 3",
	})
}

// --- Watch History ---

func (r *Router) handleGetWatchHistory(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	page, _ := strconv.Atoi(req.URL.Query().Get("page"))
	pageSize, _ := strconv.Atoi(req.URL.Query().Get("page_size"))

	history, total, err := r.userContentRepo.GetWatchHistory(req.Context(), userID, page, pageSize)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get watch history")
		return
	}

	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}

	respondJSON(w, http.StatusOK, models.PaginatedResponse{
		Data: history,
		Pagination: models.Pagination{
			Page:     page,
			PageSize: pageSize,
			Total:    total,
		},
	})
}

func (r *Router) handleUpdateWatchProgress(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var input struct {
		MovieID         string `json:"movie_id"`
		ProgressSeconds int    `json:"progress_seconds"`
		Completed       bool   `json:"completed"`
	}
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	movieID, err := uuid.Parse(input.MovieID)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	if err := r.userContentRepo.UpdateWatchProgress(req.Context(), userID, movieID, input.ProgressSeconds, input.Completed); err != nil {
		respondError(w, http.StatusInternalServerError, "failed to update watch progress")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (r *Router) handleDeleteWatchHistory(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	movieIDStr := chi.URLParam(req, "movieId")
	movieID, err := uuid.Parse(movieIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	if err := r.userContentRepo.DeleteWatchHistory(req.Context(), userID, movieID); err != nil {
		respondError(w, http.StatusNotFound, "watch history entry not found")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// --- Bookmarks ---

func (r *Router) handleGetBookmarks(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	page, _ := strconv.Atoi(req.URL.Query().Get("page"))
	pageSize, _ := strconv.Atoi(req.URL.Query().Get("page_size"))

	bookmarks, total, err := r.userContentRepo.GetBookmarks(req.Context(), userID, page, pageSize)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get bookmarks")
		return
	}

	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}

	respondJSON(w, http.StatusOK, models.PaginatedResponse{
		Data: bookmarks,
		Pagination: models.Pagination{
			Page:     page,
			PageSize: pageSize,
			Total:    total,
		},
	})
}

func (r *Router) handleAddBookmark(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var input struct {
		MovieID string `json:"movie_id"`
	}
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	movieID, err := uuid.Parse(input.MovieID)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	if err := r.userContentRepo.AddBookmark(req.Context(), userID, movieID); err != nil {
		respondError(w, http.StatusInternalServerError, "failed to add bookmark")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]string{"status": "bookmarked"})
}

func (r *Router) handleRemoveBookmark(w http.ResponseWriter, req *http.Request) {
	userID, ok := middleware.GetUserID(req.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	movieIDStr := chi.URLParam(req, "movieId")
	movieID, err := uuid.Parse(movieIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	if err := r.userContentRepo.RemoveBookmark(req.Context(), userID, movieID); err != nil {
		respondError(w, http.StatusNotFound, "bookmark not found")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "removed"})
}

// --- Cast & Crew ---

func (r *Router) handleGetMovieCredits(w http.ResponseWriter, req *http.Request) {
	idStr := chi.URLParam(req, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	// Verify movie exists
	movie, err := r.movieRepo.GetByID(req.Context(), id)
	if err != nil {
		respondError(w, http.StatusNotFound, "movie not found")
		return
	}

	cast, err := r.movieRepo.GetCastByMovieID(req.Context(), id)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get cast")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"movie_id": movie.ID,
		"title":   movie.Title,
		"cast":    cast,
	})
}

// --- Batch Movies ---

func (r *Router) handleGetMoviesByIDs(w http.ResponseWriter, req *http.Request) {
	var input struct {
		IDs []string `json:"ids"`
	}
	if err := json.NewDecoder(req.Body).Decode(&input); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(input.IDs) == 0 {
		respondJSON(w, http.StatusOK, []models.Movie{})
		return
	}

	if len(input.IDs) > 50 {
		respondError(w, http.StatusBadRequest, "too many ids (max 50)")
		return
	}

	uuids := make([]uuid.UUID, 0, len(input.IDs))
	for _, idStr := range input.IDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			respondError(w, http.StatusBadRequest, "invalid movie id: "+idStr)
			return
		}
		uuids = append(uuids, id)
	}

	movies, err := r.movieRepo.GetMoviesByIDs(req.Context(), uuids)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get movies")
		return
	}

	respondJSON(w, http.StatusOK, movies)
}

// --- Stream Sources ---

func (r *Router) handleGetStreamSources(w http.ResponseWriter, req *http.Request) {
	idStr := chi.URLParam(req, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid movie id")
		return
	}

	// Verify movie exists
	movie, err := r.movieRepo.GetByID(req.Context(), id)
	if err != nil {
		respondError(w, http.StatusNotFound, "movie not found")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"movie_id": movie.ID,
		"title":   movie.Title,
		"sources": movie.Sources,
	})
}

// --- Helpers ---

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}

func splitComma(s string) []string {
	var result []string
	for _, item := range splitTrim(s, ",") {
		if item != "" {
			result = append(result, item)
		}
	}
	return result
}

func splitTrim(s, sep string) []string {
	var result []string
	start := 0
	for i := 0; i <= len(s)-len(sep); i++ {
		if s[i:i+len(sep)] == sep {
			result = append(result, s[start:i])
			start = i + len(sep)
		}
	}
	result = append(result, s[start:])
	return result
}
