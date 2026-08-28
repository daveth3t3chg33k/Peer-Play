package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/peerplay/server/internal/models"
)

// UserRepository defines the interface for user data access
type UserRepository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	GetByEmail(ctx context.Context, email string) (*models.User, error)
	Create(ctx context.Context, user *models.User) error
	Update(ctx context.Context, user *models.User) error
	Delete(ctx context.Context, id uuid.UUID) error
}

type userRepository struct {
	db *DB
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *DB) UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User

	query := `
		SELECT id, email, password_hash, display_name, device_fingerprint, created_at, updated_at
		FROM users WHERE id = $1`

	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.DisplayName,
		&user.DeviceFingerprint, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *userRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User

	query := `
		SELECT id, email, password_hash, display_name, device_fingerprint, created_at, updated_at
		FROM users WHERE email = $1`

	err := r.db.Pool.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.DisplayName,
		&user.DeviceFingerprint, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}

	return &user, nil
}

func (r *userRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, display_name, device_fingerprint)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING created_at, updated_at`

	return r.db.Pool.QueryRow(ctx, query,
		user.ID, user.Email, user.PasswordHash, user.DisplayName, user.DeviceFingerprint,
	).Scan(&user.CreatedAt, &user.UpdatedAt)
}

func (r *userRepository) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET display_name = $2, device_fingerprint = $3, updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at`

	return r.db.Pool.QueryRow(ctx, query,
		user.ID, user.DisplayName, user.DeviceFingerprint,
	).Scan(&user.UpdatedAt)
}

func (r *userRepository) Delete(ctx context.Context, id uuid.UUID) error {
	result, err := r.db.Pool.Exec(ctx, "DELETE FROM users WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}
	return nil
}
