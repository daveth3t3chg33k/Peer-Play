package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all application configuration
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	DHT      DHTConfig
}

// ServerConfig holds HTTP server settings
type ServerConfig struct {
	Port         int
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
	Environment  string // development, staging, production
}

// DatabaseConfig holds PostgreSQL settings
type DatabaseConfig struct {
	Host         string
	Port         int
	User         string
	Password     string
	DBName       string
	SSLMode      string
	MaxOpenConns int
	MaxIdleConns int
}

// RedisConfig holds Redis settings
type RedisConfig struct {
	Addr     string
	Password string
	DB       int
}

// JWTConfig holds JWT authentication settings
type JWTConfig struct {
	Secret          string
	ExpirationHours int
	Issuer          string
}

// DHTConfig holds DHT bootstrap node settings
type DHTConfig struct {
	Port         int
	BootstrapURL string
	NodeID       string
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	// Ignore error — .env file is optional
	_ = godotenv.Load() //nolint:errcheck // .env file is optional, safe to ignore

	port := mustAtoi(getEnv("SERVER_PORT", "8080"))
	dbPort := mustAtoi(getEnv("DB_PORT", "5432"))
	redisDB := mustAtoi(getEnv("REDIS_DB", "0"))
	jwtExp := mustAtoi(getEnv("JWT_EXPIRATION_HOURS", "72"))
	dhtPort := mustAtoi(getEnv("DHT_PORT", "6881"))
	maxOpen := mustAtoi(getEnv("DB_MAX_OPEN_CONNS", "25"))
	maxIdle := mustAtoi(getEnv("DB_MAX_IDLE_CONNS", "5"))

	cfg := &Config{
		Server: ServerConfig{
			Port:         port,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 15 * time.Second,
			IdleTimeout:  60 * time.Second,
			Environment:  getEnv("APP_ENV", "development"),
		},
		Database: DatabaseConfig{
			Host:         getEnv("DB_HOST", "localhost"),
			Port:         dbPort,
			User:         getEnv("DB_USER", "peerplay"),
			Password:     getEnv("DB_PASSWORD", "peerplay_secret"),
			DBName:       getEnv("DB_NAME", "peerplay"),
			SSLMode:      getEnv("DB_SSLMODE", "disable"),
			MaxOpenConns: maxOpen,
			MaxIdleConns: maxIdle,
		},
		Redis: RedisConfig{
			Addr:     getEnv("REDIS_ADDR", "localhost:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       redisDB,
		},
		JWT: JWTConfig{
			Secret:          getEnv("JWT_SECRET", "change-me-in-production"),
			ExpirationHours: jwtExp,
			Issuer:          "peerplay",
		},
		DHT: DHTConfig{
			Port:         dhtPort,
			BootstrapURL: getEnv("DHT_BOOTSTRAP_URL", ""),
			NodeID:       getEnv("DHT_NODE_ID", ""),
		},
	}

	return cfg, nil
}

// DatabaseConnectionString returns the PostgreSQL connection string
func (d *DatabaseConfig) DatabaseConnectionString() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode,
	)
}

// DatabaseDSN returns the DSN for pgx
func (d *DatabaseConfig) DatabaseDSN() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		d.User, d.Password, d.Host, d.Port, d.DBName, d.SSLMode,
	)
}

func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// mustAtoi converts a string to int, returning 0 on error.
func mustAtoi(s string) int {
	v, _ := strconv.Atoi(s)
	return v
}
