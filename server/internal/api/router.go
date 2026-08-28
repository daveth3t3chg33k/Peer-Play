package api

import (
	"log/slog"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/peerplay/server/internal/config"
	"github.com/peerplay/server/internal/dht"
	"github.com/peerplay/server/internal/middleware"
	"github.com/peerplay/server/internal/repository"
)

// Router holds all dependencies for the API
type Router struct {
	cfg             *config.Config
	movieRepo       repository.MovieRepository
	userRepo        repository.UserRepository
	userContentRepo repository.UserContentRepository
	dhtNode         *dht.Node
	logger          *slog.Logger
	startTime       time.Time
}

// NewRouter creates a new API router with all dependencies
func NewRouter(
	cfg *config.Config,
	movieRepo repository.MovieRepository,
	userRepo repository.UserRepository,
	userContentRepo repository.UserContentRepository,
	dhtNode *dht.Node,
	logger *slog.Logger,
) *Router {
	return &Router{
		cfg:             cfg,
		movieRepo:       movieRepo,
		userRepo:        userRepo,
		userContentRepo: userContentRepo,
		dhtNode:         dhtNode,
		logger:          logger,
		startTime:       time.Now(),
	}
}

// Setup configures and returns the chi mux
func (r *Router) Setup() *chi.Mux {
	mux := chi.NewRouter()

	// Global middleware
	mux.Use(chimw.RealIP)
	mux.Use(middleware.RequestID)
	mux.Use(middleware.Logger(r.logger))
	mux.Use(middleware.Recoverer(r.logger))
	mux.Use(chimw.Heartbeat("/ping"))
	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Device-Fingerprint", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check (no auth required)
	mux.Get("/health", r.handleHealth)

	// API v1 routes
	mux.Route("/api/v1", func(v1 chi.Router) {
		// Public routes
		v1.Post("/auth/register", r.handleRegister)
		v1.Post("/auth/login", r.handleLogin)

		// Protected routes
		v1.Group(func(protected chi.Router) {
			protected.Use(middleware.AuthMiddleware(&r.cfg.JWT))

			// Movies
			protected.Get("/movies", r.handleListMovies)
			protected.Get("/movies/trending", r.handleTrendingMovies)
			protected.Get("/movies/recent", r.handleRecentMovies)
			protected.Get("/movies/{id}", r.handleGetMovie)
			protected.Get("/movies/search", r.handleSearchMovies)

			// User
			protected.Get("/me", r.handleGetCurrentUser)

			// Vault / Downloads
			protected.Get("/vault", r.handleGetVault)

			// Watch History
			protected.Get("/watch-history", r.handleGetWatchHistory)
			protected.Put("/watch-history", r.handleUpdateWatchProgress)
			protected.Delete("/watch-history/{movieId}", r.handleDeleteWatchHistory)

			// Bookmarks
			protected.Get("/bookmarks", r.handleGetBookmarks)
			protected.Post("/bookmarks", r.handleAddBookmark)
			protected.Delete("/bookmarks/{movieId}", r.handleRemoveBookmark)
		})

		// DHT node routes (public)
		v1.Route("/dht", func(dhtRouter chi.Router) {
			dhtHandler := dht.NewHandler(r.dhtNode)
			dhtRouter.Mount("/", dhtHandler.Routes())
		})
	})

	return mux
}
