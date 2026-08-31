-- Migration 003: Add video sources with magnet links for torrent streaming
-- These are sample magnet links for testing the P2P streaming feature

INSERT INTO video_sources (movie_id, quality, magnet_link, file_size_bytes, codec) VALUES
-- Dune: Part Two
((SELECT id FROM movies WHERE title = 'Dune: Part Two' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0&dn=Dune+Part+Two+2024+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x265'),
((SELECT id FROM movies WHERE title = 'Dune: Part Two' LIMIT 1), '720p', 'magnet:?xt=urn:btih:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b1&dn=Dune+Part+Two+2024+720p&tr=udp://tracker.opentrackr.org:1337/announce', 2147483648, 'x264'),

-- Oppenheimer
((SELECT id FROM movies WHERE title = 'Oppenheimer' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1&dn=Oppenheimer+2023+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 5368709120, 'x265'),
((SELECT id FROM movies WHERE title = 'Oppenheimer' LIMIT 1), '4K', 'magnet:?xt=urn:btih:b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c2&dn=Oppenheimer+2023+2160p&tr=udp://tracker.opentrackr.org:1337/announce', 10737418240, 'x265'),

-- The Batman
((SELECT id FROM movies WHERE title = 'The Batman' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3&dn=The+Batman+2022+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4831838208, 'x264'),
((SELECT id FROM movies WHERE title = 'The Batman' LIMIT 1), '720p', 'magnet:?xt=urn:btih:d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e4&dn=The+Batman+2022+720p&tr=udp://tracker.opentrackr.org:1337/announce', 2684354560, 'x264'),

-- The Shawshank Redemption
((SELECT id FROM movies WHERE title = 'The Shawshank Redemption' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0&dn=The+Shawshank+Redemption+1994+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- The Godfather
((SELECT id FROM movies WHERE title = 'The Godfather' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1&dn=The+Godfather+1972+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x264'),

-- The Dark Knight
((SELECT id FROM movies WHERE title = 'The Dark Knight' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2&dn=The+Dark+Knight+2008+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x264'),

-- Interstellar
((SELECT id FROM movies WHERE title = 'Interstellar' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3&dn=Interstellar+2014+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4831838208, 'x265'),
((SELECT id FROM movies WHERE title = 'Interstellar' LIMIT 1), '720p', 'magnet:?xt=urn:btih:f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a4&dn=Interstellar+2014+720p&tr=udp://tracker.opentrackr.org:1337/announce', 2684354560, 'x264'),

-- The Matrix
((SELECT id FROM movies WHERE title = 'The Matrix' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7&dn=The+Matrix+1999+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x264'),

-- Inception
((SELECT id FROM movies WHERE title = 'Inception' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8&dn=Inception+2010+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x264'),

-- Pulp Fiction
((SELECT id FROM movies WHERE title = 'Pulp Fiction' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5&dn=Pulp+Fiction+1994+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x264'),

-- Fight Club
((SELECT id FROM movies WHERE title = 'Fight Club' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6&dn=Fight+Club+1999+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x264'),

-- Forrest Gump
((SELECT id FROM movies WHERE title = 'Forrest Gump' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7&dn=Forrest+Gump+1994+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x264'),

-- Mad Max: Fury Road
((SELECT id FROM movies WHERE title = 'Mad Max: Fury Road' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8&dn=Mad+Max+Fury+Road+2015+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x264'),

-- Gladiator
((SELECT id FROM movies WHERE title = 'Gladiator' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9&dn=Gladiator+2000+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x264'),

-- Spider-Man: Into the Spider-Verse
((SELECT id FROM movies WHERE title = 'Spider-Man: Into the Spider-Verse' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8ea&dn=Spider-Man+Into+the+Spider-Verse+2018+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Coco
((SELECT id FROM movies WHERE title = 'Coco' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f1&dn=Coco+2017+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Spirited Away
((SELECT id FROM movies WHERE title = 'Spirited Away' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b3&dn=Spirited+Away+2001+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Hereditary
((SELECT id FROM movies WHERE title = 'Hereditary' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f5&dn=Hereditary+2018+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Get Out
((SELECT id FROM movies WHERE title = 'Get Out' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a6&dn=Get+Out+2017+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Parasite
((SELECT id FROM movies WHERE title = 'Parasite' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9&dn=Parasite+2019+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Blade Runner 2049
((SELECT id FROM movies WHERE title = 'Blade Runner 2049' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4&dn=Blade+Runner+2049+2017+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4831838208, 'x265'),

-- Top Gun: Maverick
((SELECT id FROM movies WHERE title = 'Top Gun: Maverick' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0&dn=Top+Gun+Maverick+2022+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x264'),

-- John Wick
((SELECT id FROM movies WHERE title = 'John Wick' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2&dn=John+Wick+2014+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- Your Name
((SELECT id FROM movies WHERE title = 'Your Name' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a2&dn=Your+Name+2016+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3221225472, 'x264'),

-- WALL-E
((SELECT id FROM movies WHERE title = 'WALL-E' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c4&dn=WALL-E+2008+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 2684354560, 'x264'),

-- Poor Things
((SELECT id FROM movies WHERE title = 'Poor Things' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2&dn=Poor+Things+2023+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 4294967296, 'x265'),

-- Everything Everywhere All at Once
((SELECT id FROM movies WHERE title = 'Everything Everywhere All at Once' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b1&dn=Everything+Everywhere+All+at+Once+2022+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 3758096384, 'x265'),

-- Whiplash
((SELECT id FROM movies WHERE title = 'Whiplash' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c2&dn=Whiplash+2014+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 2684354560, 'x264'),

-- Killers of the Flower Moon
((SELECT id FROM movies WHERE title = 'Killers of the Flower Moon' LIMIT 1), '1080p', 'magnet:?xt=urn:btih:e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4&dn=Killers+of+the+Flower+Moon+2023+1080p&tr=udp://tracker.opentrackr.org:1337/announce', 5368709120, 'x265');
