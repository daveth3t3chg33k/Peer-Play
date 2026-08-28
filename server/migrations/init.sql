-- PeerPlay Database Schema
-- Migration 001: Initial Schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) DEFAULT '',
    device_fingerprint VARCHAR(255) DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- Movies table
CREATE TABLE IF NOT EXISTS movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT DEFAULT '',
    release_year INTEGER DEFAULT 0,
    genres TEXT[] DEFAULT '{}',
    poster_url TEXT DEFAULT '',
    backdrop_url TEXT DEFAULT '',
    duration_minutes INTEGER DEFAULT 0,
    rating DECIMAL(3,1) DEFAULT 0.0,
    info_hash VARCHAR(40) DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movies_title ON movies USING GIN (to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_movies_year ON movies (release_year);
CREATE INDEX IF NOT EXISTS idx_movies_rating ON movies (rating DESC NULLS LAST);

-- Video Sources table
CREATE TABLE IF NOT EXISTS video_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movie_id UUID NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    quality VARCHAR(10) NOT NULL DEFAULT '1080p',
    magnet_link TEXT DEFAULT '',
    file_size_bytes BIGINT DEFAULT 0,
    codec VARCHAR(50) DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_video_sources_movie ON video_sources (movie_id);

-- Subtitles table
CREATE TABLE IF NOT EXISTS subtitles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movie_id UUID NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL,
    language_name VARCHAR(100) NOT NULL DEFAULT '',
    file_url TEXT DEFAULT '',
    format VARCHAR(10) DEFAULT 'srt',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subtitles_movie ON subtitles (movie_id);
CREATE INDEX IF NOT EXISTS idx_subtitles_language ON subtitles (language_code);

-- Watch History table
CREATE TABLE IF NOT EXISTS watch_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    progress_seconds INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    last_watched_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_watch_history_user ON watch_history (user_id);

-- Bookmarks table
CREATE TABLE IF NOT EXISTS bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks (user_id);

-- Seed data: sample movies
INSERT INTO movies (title, description, release_year, genres, poster_url, backdrop_url, duration_minutes, rating, info_hash) VALUES
('The Matrix', 'A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.', 1999, ARRAY['Action', 'Sci-Fi'], 'https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg', 'https://image.tmdb.org/t/p/original/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg', 136, 8.7, 'a8b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9'),
('Inception', 'A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.', 2010, ARRAY['Action', 'Sci-Fi', 'Thriller'], 'https://image.tmdb.org/t/p/w500/ljsZTbVsrQSqZgWeep2B1QiDKuh.jpg', 'https://image.tmdb.org/t/p/original/s3TBrRGB1iav7gFOCNx3H31MoES.jpg', 148, 8.8, 'b9c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0'),
('Interstellar', 'The adventures of a group of explorers who make use of a newly discovered wormhole to surpass the limitations on human space travel and conquer the vast distances involved in an interstellar voyage.', 2014, ARRAY['Adventure', 'Drama', 'Sci-Fi'], 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg', 'https://image.tmdb.org/t/p/original/xJHokMbljvjADYdit5fK1DhoXV1.jpg', 169, 8.6, 'c0d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1'),
('The Dark Knight', 'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.', 2008, ARRAY['Action', 'Crime', 'Drama'], 'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911BTUgMe1nF1iC.jpg', 'https://image.tmdb.org/t/p/original/nMKdUUepR0i5zn0y1T4CsSB5ez.jpg', 152, 9.0, 'd1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2'),
('Pulp Fiction', 'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.', 1994, ARRAY['Crime', 'Drama', 'Thriller'], 'https://image.tmdb.org/t/p/w500/d5iIlFn5s0IhQirytPdqhLO6J1.jpg', 'https://image.tmdb.org/t/p/original/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg', 154, 8.9, 'e2f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3')
ON CONFLICT DO NOTHING;
