-- Migration 007: real, legal, well-seeded stream sources.
--
-- Migration 003 seeded magnet links with fabricated info-hashes (e.g.
-- a1b2c3d4e5f6...) that have no swarm behind them, so every P2P playback
-- attempt silently stalled and fell back to a demo URL.
--
-- This replaces those placeholders with Blender Foundation open movies.
-- They are Creative Commons licensed (free to redistribute and share) and are
-- actively seeded, so the torrent engine can genuinely resolve metadata and
-- stream bytes. These titles are also added to the catalogue so they are
-- actually reachable in the UI.

-- Drop the fabricated sample sources (003 was the only source of them).
DELETE FROM video_sources WHERE magnet_link <> '';

-- Catalogue entries for the open movies, idempotent on title.
INSERT INTO movies (title, description, release_year, genres, poster_url, backdrop_url, duration_minutes, rating, info_hash)
SELECT * FROM (VALUES
    ('Sintel',
     'A lonely young woman travels the land in search of a dragon she once befriended. An open movie by the Blender Foundation.',
     2010, ARRAY['Animation', 'Fantasy', 'Short'], 'https://archive.org/services/img/Sintel',
     'https://archive.org/services/img/Sintel', 15, 7.6, '08ada5a7a6183aae1e09d831df6748d566095a10'),
    ('Big Buck Bunny',
     'A large and lovable rabbit deals with three tiny bullies. The first Blender Foundation open movie.',
     2008, ARRAY['Animation', 'Comedy', 'Short'], 'https://archive.org/services/img/BigBuckBunny_124',
     'https://archive.org/services/img/BigBuckBunny_124', 10, 7.8, 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c'),
    ('Tears of Steel',
     'A group of warriors and scientists gather to prevent a future catastrophe in this sci-fi short from the Blender Foundation.',
     2012, ARRAY['Sci-Fi', 'Short'], 'https://archive.org/services/img/TearsOfSteel',
     'https://archive.org/services/img/TearsOfSteel', 12, 6.9, '209c8226b299b308beaf2b9cd3fb49212dbd13ec'),
    ('Cosmos Laundromat',
     'A suicidal sheep on a desolate island meets an eccentric salesman offering him the life of his dreams.',
     2015, ARRAY['Animation', 'Fantasy', 'Short'], 'https://archive.org/services/img/CosmosLaundromatFirstContact',
     'https://archive.org/services/img/CosmosLaundromatFirstContact', 12, 7.3, 'c9e15763f722f23e98a29decdfae341b98d53056')
) AS v(title, description, release_year, genres, poster_url, backdrop_url, duration_minutes, rating, info_hash)
WHERE NOT EXISTS (SELECT 1 FROM movies m WHERE m.title = v.title);

-- Real magnet links. The trackers are the public ones proven to return peers.
INSERT INTO video_sources (movie_id, quality, magnet_link, file_size_bytes, codec)
SELECT m.id, v.quality, v.magnet_link, v.file_size_bytes, v.codec
FROM (VALUES
    ('Sintel', '1080p',
     'magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10&dn=Sintel&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce',
     129302391, 'h264'),
    ('Big Buck Bunny', '1080p',
     'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce',
     276445467, 'h264'),
    ('Tears of Steel', '1080p',
     'magnet:?xt=urn:btih:209c8226b299b308beaf2b9cd3fb49212dbd13ec&dn=Tears+of+Steel&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce',
     571426507, 'h264'),
    ('Cosmos Laundromat', '1080p',
     'magnet:?xt=urn:btih:c9e15763f722f23e98a29decdfae341b98d53056&dn=Cosmos+Laundromat&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce',
     220864086, 'h264')
) AS v(title, quality, magnet_link, file_size_bytes, codec)
JOIN movies m ON m.title = v.title
WHERE NOT EXISTS (SELECT 1 FROM video_sources s WHERE s.movie_id = m.id);
