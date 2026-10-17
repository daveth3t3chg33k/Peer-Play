-- Migration 008: playable library.
--
-- Only titles that have a real, legal source are listed by the catalogue API
-- after this migration (see movie_repo.go). This adds the direct-HTTP source
-- type and seeds public-domain films hosted by the Internet Archive.
--
-- Every URL below was checked to answer `206 Partial Content` with
-- `Content-Type: video/mp4` and `Accept-Ranges: bytes`, so ExoPlayer can start
-- playing and seek before the whole file is downloaded. The works are in the
-- public domain or CC0 (as marked on their Internet Archive items); attribution
-- is recorded in each movie description.

ALTER TABLE video_sources ADD COLUMN IF NOT EXISTS stream_url TEXT DEFAULT '';

-- Catalogue entries (idempotent on title).
INSERT INTO movies (title, description, release_year, genres, poster_url, backdrop_url, duration_minutes, rating, info_hash, category)
SELECT * FROM (VALUES
    ('Night of the Living Dead',
     'Seven people barricade themselves in a Pennsylvania farmhouse as the recently dead rise. Public domain (Internet Archive).',
     1968, ARRAY['Horror', 'Thriller'], 'https://archive.org/services/img/Night.Of.The.Living.Dead_1080p',
     'https://archive.org/services/img/Night.Of.The.Living.Dead_1080p', 96, 7.8, '', 'horror'),
    ('Nosferatu',
     'F. W. Murnau''s silent vampire classic. Public domain (CC0 on Internet Archive).',
     1922, ARRAY['Horror', 'Fantasy'], 'https://archive.org/services/img/Nosferatu1922',
     'https://archive.org/services/img/Nosferatu1922', 94, 7.9, '', 'horror'),
    ('Plan 9 from Outer Space',
     'Ed Wood''s famously eccentric alien-invasion film. Public domain (CC0 on Internet Archive).',
     1959, ARRAY['Sci-Fi', 'Horror'], 'https://archive.org/services/img/plan-9-from-outer-space',
     'https://archive.org/services/img/plan-9-from-outer-space', 79, 4.0, '', 'scifi'),
    ('The Little Shop of Horrors',
     'Roger Corman''s comedy about a florist''s man-eating plant. Public domain (Internet Archive).',
     1960, ARRAY['Comedy', 'Horror'], 'https://archive.org/services/img/The_Little_Shop_of_Horrors.mpeg',
     'https://archive.org/services/img/The_Little_Shop_of_Horrors.mpeg', 72, 6.2, '', 'comedy'),
    ('Sherlock Jr.',
     'Buster Keaton dreams his way into the movie he is projecting. Public domain (Internet Archive).',
     1924, ARRAY['Comedy', 'Action'], 'https://archive.org/services/img/sherlockjr1924_201909',
     'https://archive.org/services/img/sherlockjr1924_201909', 45, 8.2, '', 'comedy'),
    ('The General',
     'Buster Keaton''s locomotive chase through the Civil War. Public domain (Internet Archive).',
     1926, ARRAY['Comedy', 'Action', 'War'], 'https://archive.org/services/img/TheGeneral1926',
     'https://archive.org/services/img/TheGeneral1926', 78, 8.1, '', 'action'),
    ('His Girl Friday',
     'A newspaper editor schemes to keep his ace reporter ex-wife on the payroll. Public domain (Internet Archive).',
     1940, ARRAY['Comedy', 'Romance', 'Drama'], 'https://archive.org/services/img/his_girl_friday',
     'https://archive.org/services/img/his_girl_friday', 92, 7.9, '', 'romance'),
    ('Carnival of Souls',
     'A woman is drawn to an abandoned pavilion after surviving a car crash. Public domain (Internet Archive).',
     1962, ARRAY['Horror', 'Thriller'], 'https://archive.org/services/img/carnival_of_souls',
     'https://archive.org/services/img/carnival_of_souls', 78, 7.0, '', 'thriller'),
    ('Detour',
     'A hitchhiker''s luck turns bad in this noir staple. Public domain (Internet Archive).',
     1945, ARRAY['Crime', 'Drama', 'Thriller'], 'https://archive.org/services/img/Detour',
     'https://archive.org/services/img/Detour', 68, 7.3, '', 'crime'),
    ('Sita Sings the Blues',
     'Nina Paley''s animated retelling of the Ramayana, set to 1920s jazz. CC0 (Internet Archive).',
     2008, ARRAY['Animation', 'Music', 'Fantasy'], 'https://archive.org/services/img/Sita_Sings_the_Blues',
     'https://archive.org/services/img/Sita_Sings_the_Blues', 82, 7.1, '', 'animation')
) AS v(title, description, release_year, genres, poster_url, backdrop_url, duration_minutes, rating, info_hash, category)
WHERE NOT EXISTS (SELECT 1 FROM movies m WHERE m.title = v.title);

-- Direct-HTTP sources, verified for range streaming.
INSERT INTO video_sources (movie_id, quality, magnet_link, stream_url, file_size_bytes, codec)
SELECT m.id, v.quality, '', v.stream_url, v.file_size_bytes, v.codec
FROM (VALUES
    ('Night of the Living Dead', '720p',
     'https://archive.org/download/Night.Of.The.Living.Dead_1080p/NightOfTheLivingDead_720p_512kb.mp4',
     406937525, 'h264'),
    ('Nosferatu', '480p',
     'https://archive.org/download/Nosferatu1922/Nosferatu.mp4', 574390206, 'h264'),
    ('Plan 9 from Outer Space', '480p',
     'https://archive.org/download/plan-9-from-outer-space/plan-9-from-outer-space.mp4', 454359304, 'h264'),
    ('The Little Shop of Horrors', '480p',
     'https://archive.org/download/The_Little_Shop_of_Horrors.mpeg/The_Little_Shop_of_Horrors.mp4', 452745287, 'h264'),
    ('Sherlock Jr.', '720p',
     'https://archive.org/download/sherlockjr1924_201909/Sherlock%20Jr.%20-%20Buster%20Keaton%20%281924%29%20HD%20%5B720p%5D.mp4',
     354283591, 'h264'),
    ('The General', '480p',
     'https://archive.org/download/TheGeneral1926/The_General_1926_720p_512kb.mp4', 419224226, 'h264'),
    ('His Girl Friday', '480p',
     'https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4', 401207987, 'h264'),
    ('Carnival of Souls', '480p',
     'https://archive.org/download/carnival_of_souls/carnival_of_souls.mp4', 424348509, 'h264'),
    ('Detour', '480p',
     'https://archive.org/download/Detour/Detour_512kb.mp4', 294622587, 'h264'),
    ('Sita Sings the Blues', '360p',
     'https://archive.org/download/Sita_Sings_the_Blues/Sita_Sings_the_Blues_small.mp4', 223616052, 'h264')
) AS v(title, quality, stream_url, file_size_bytes, codec)
JOIN movies m ON m.title = v.title
WHERE NOT EXISTS (
    SELECT 1 FROM video_sources s
    WHERE s.movie_id = m.id AND s.stream_url = v.stream_url
);
