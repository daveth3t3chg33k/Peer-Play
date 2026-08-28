package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/peerplay/server/internal/config"
)

type contextKey string

const (
	UserIDKey    contextKey = "user_id"
	UserEmailKey contextKey = "user_email"
)

// Claims represents the JWT claims
type Claims struct {
	UserID            string `json:"user_id"`
	Email             string `json:"email"`
	DeviceFingerprint string `json:"device_fingerprint"`
	jwt.RegisteredClaims
}

// AuthMiddleware validates JWT tokens and binds device fingerprint
func AuthMiddleware(cfg *config.JWTConfig) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				http.Error(w, `{"error":"missing authorization header"}`, http.StatusUnauthorized)
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				http.Error(w, `{"error":"invalid authorization format"}`, http.StatusUnauthorized)
				return
			}

			tokenString := parts[1]
			claims := &Claims{}

			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				return []byte(cfg.Secret), nil
			})
			if err != nil || !token.Valid {
				http.Error(w, `{"error":"invalid or expired token"}`, http.StatusUnauthorized)
				return
			}

			// Validate device fingerprint binding
			deviceFP := r.Header.Get("X-Device-Fingerprint")
			if deviceFP != "" && claims.DeviceFingerprint != "" && deviceFP != claims.DeviceFingerprint {
				http.Error(w, `{"error":"device fingerprint mismatch"}`, http.StatusUnauthorized)
				return
			}

			// Extract user info into context
			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			ctx = context.WithValue(ctx, UserEmailKey, claims.Email)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUserID extracts user ID from request context
func GetUserID(ctx context.Context) (uuid.UUID, bool) {
	userIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(userIDStr)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

// GetUserEmail extracts user email from request context
func GetUserEmail(ctx context.Context) (string, bool) {
	email, ok := ctx.Value(UserEmailKey).(string)
	return email, ok
}
