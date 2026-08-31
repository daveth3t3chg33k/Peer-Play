-- Migration 004: Cast Members table + seed data

CREATE TABLE IF NOT EXISTS cast_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movie_id UUID NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    character VARCHAR(255) DEFAULT '',
    profile_path TEXT DEFAULT '',
    department VARCHAR(50) DEFAULT 'Acting',
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cast_members_movie ON cast_members (movie_id);
CREATE INDEX IF NOT EXISTS idx_cast_members_order ON cast_members (movie_id, sort_order);

-- Seed cast for The Shawshank Redemption (first trending movie)
-- We'll seed a few key movies with real-ish cast data using TMDB profile paths

-- The Shawshank Redemption
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Tim Robbins', 'Andy Dufresne', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Morgan Freeman', 'Ellis Boyd Redding', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Bob Gunton', 'Warden Samuel Norton', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'William Sadler', 'Heywood', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Clancy Brown', 'Captain Byron Hadley', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Gil Bellows', 'Tommy Williams', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 6
FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1;

-- The Godfather
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Marlon Brando', 'Don Vito Corleone', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'The Godfather' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Al Pacino', 'Michael Corleone', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'The Godfather' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'James Caan', 'Sonny Corleone', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'The Godfather' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Robert Duvall', 'Tom Hagen', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'The Godfather' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Diane Keaton', 'Kay Adams', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'The Godfather' LIMIT 1;

-- The Dark Knight
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Christian Bale', 'Bruce Wayne / Batman', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'The Dark Knight' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Heath Ledger', 'The Joker', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'The Dark Knight' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Aaron Eckhart', 'Harvey Dent', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'The Dark Knight' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Gary Oldman', 'Lt. James Gordon', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'The Dark Knight' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Maggie Gyllenhaal', 'Rachel Dawes', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'The Dark Knight' LIMIT 1;

-- Inception
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Leonardo DiCaprio', 'Dom Cobb', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'Inception' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Joseph Gordon-Levitt', 'Arthur', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'Inception' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Elliot Page', 'Ariadne', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'Inception' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Tom Hardy', 'Eames', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'Inception' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Ken Watanabe', 'Saito', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'Inception' LIMIT 1;

-- Interstellar
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Matthew McConaughey', 'Joseph Cooper', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'Interstellar' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Anne Hathaway', 'Dr. Amelia Brand', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'Interstellar' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Jessica Chastain', 'Murph', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'Interstellar' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Michael Caine', 'Professor John Brand', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'Interstellar' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Matt Damon', 'Dr. Mann', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'Interstellar' LIMIT 1;

-- Pulp Fiction
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'John Travolta', 'Vincent Vega', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'Pulp Fiction' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Samuel L. Jackson', 'Jules Winnfield', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'Pulp Fiction' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Uma Thurman', 'Mia Wallace', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'Pulp Fiction' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Bruce Willis', 'Butch Coolidge', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'Pulp Fiction' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Harvey Keitel', 'The Wolf', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'Pulp Fiction' LIMIT 1;

-- Fight Club
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Brad Pitt', 'Tyler Durden', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'Fight Club' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Edward Norton', 'The Narrator', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'Fight Club' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Helena Bonham Carter', 'Marla Singer', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'Fight Club' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Meat Loaf', 'Robert Paulson', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'Fight Club' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Jared Leto', 'Angel Face', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'Fight Club' LIMIT 1;

-- The Matrix
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Keanu Reeves', 'Neo', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'The Matrix' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Laurence Fishburne', 'Morpheus', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'The Matrix' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Carrie-Anne Moss', 'Trinity', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'The Matrix' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Hugo Weaving', 'Agent Smith', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'The Matrix' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Joe Pantoliano', 'Cypher', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'The Matrix' LIMIT 1;

-- Parasite
INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Song Kang-ho', 'Kim Ki-taek', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 1
FROM movies WHERE title = 'Parasite' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Lee Sun-kyun', 'Park Dong-ik', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 2
FROM movies WHERE title = 'Parasite' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Cho Yeo-jeong', 'Choi Yeon-gyo', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 3
FROM movies WHERE title = 'Parasite' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Choi Woo-shik', 'Kim Ki-woo', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 4
FROM movies WHERE title = 'Parasite' LIMIT 1;

INSERT INTO cast_members (movie_id, name, character, profile_path, department, sort_order)
SELECT id, 'Park So-dam', 'Kim Ki-jung', 'https://image.tmdb.org/t/p/w185/oIciQWr8VbtiVFArVoR4yE993fQ.jpg', 'Acting', 5
FROM movies WHERE title = 'Parasite' LIMIT 1;
