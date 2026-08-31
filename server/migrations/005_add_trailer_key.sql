-- Add youtube_trailer_key column to movies
ALTER TABLE movies ADD COLUMN IF NOT EXISTS youtube_trailer_key VARCHAR(32) DEFAULT '';

-- Seed real YouTube trailer keys for popular movies
UPDATE movies SET youtube_trailer_key = 'PLl99DlL6b4' WHERE title = 'The Shawshank Redemption';
UPDATE movies SET youtube_trailer_key = 'UaVTIH8mujA' WHERE title = 'The Godfather';
UPDATE movies SET youtube_trailer_key = 'EXeTwQWrcwY' WHERE title = 'The Dark Knight';
UPDATE movies SET youtube_trailer_key = 'YoHD9XEInc0' WHERE title = 'Inception';
UPDATE movies SET youtube_trailer_key = 'zSWdZVtXT7E' WHERE title = 'Interstellar';
UPDATE movies SET youtube_trailer_key = 's7EdlFFVCwo' WHERE title = 'Pulp Fiction';
UPDATE movies SET youtube_trailer_key = 'QtRPoMZeE14' WHERE title = 'Fight Club';
UPDATE movies SET youtube_trailer_key = 'vKQi3bBA1y8' WHERE title = 'The Matrix';
UPDATE movies SET youtube_trailer_key = '5xH0HfJHsaY' WHERE title = 'Parasite';
UPDATE movies SET youtube_trailer_key = 'hT_nvWreIhg' WHERE title = 'The Lord of the Rings: The Return of the King';
UPDATE movies SET youtube_trailer_key = '4F1EF1GsC6g' WHERE title = 'Gladiator';
UPDATE movies SET youtube_trailer_key = 'i-DoKJ1CRzU' WHERE title = 'Forrest Gump';
