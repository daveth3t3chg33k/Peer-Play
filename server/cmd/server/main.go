package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/peerplay/server/internal/api"
	"github.com/peerplay/server/internal/config"
	"github.com/peerplay/server/internal/dht"
	"github.com/peerplay/server/internal/repository"
)

func main() {
	// Setup structured logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	logger.Info("starting PeerPlay server")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		logger.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Connect to database
	db, err := repository.NewDatabase(&cfg.Database)
	if err != nil {
		logger.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	logger.Info("connected to database")

	// Initialize repositories
	movieRepo := repository.NewMovieRepository(db)
	userRepo := repository.NewUserRepository(db)
	userContentRepo := repository.NewUserContentRepository(db)

	// Initialize DHT node
	dhtNode := dht.NewNode(dht.Config{
		Port:               cfg.DHT.Port,
		NodeID:             cfg.DHT.NodeID,
		BootstrapURL:       cfg.DHT.BootstrapURL,
		AnnounceInterval:   30 * time.Second,
		MaxPeersPerTorrent: 200,
	}, logger)
	if err := dhtNode.Start(); err != nil {
		logger.Error("failed to start DHT node", "error", err)
		os.Exit(1)
	}
	defer dhtNode.Stop()
	logger.Info("DHT node started", "port", cfg.DHT.Port)

	// Setup router
	router := api.NewRouter(cfg, movieRepo, userRepo, userContentRepo, dhtNode, logger)
	mux := router.Setup()

	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      mux,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
		IdleTimeout:  cfg.Server.IdleTimeout,
	}

	// Start server in goroutine
	go func() {
		logger.Info("server listening", "port", cfg.Server.Port, "environment", cfg.Server.Environment)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("shutting down server")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("server forced to shutdown", "error", err)
	}

	logger.Info("server stopped")
}
