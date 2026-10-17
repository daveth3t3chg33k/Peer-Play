import 'package:flutter_test/flutter_test.dart';

import 'package:peerplay/services/playback_source_resolver.dart';

void main() {
  group('PlaybackSourceResolver', () {
    test('returns a direct URL without touching the torrent engine', () async {
      var engineCalls = 0;
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async {
          engineCalls++;
          return true;
        },
      );

      final source = await resolver.resolve(
        directUrl: '  https://media.example.com/movie.mp4 ',
      );

      expect(source.kind, PlaybackKind.direct);
      expect(source.uri.toString(), 'https://media.example.com/movie.mp4');
      expect(source.torrentId, isNull);
      expect(engineCalls, 0);
    });

    test('throws when the title has no source at all', () async {
      final resolver = PlaybackSourceResolver();

      await expectLater(
        resolver.resolve(magnetLink: '   ', directUrl: ''),
        throwsA(
          isA<PlaybackException>().having(
            (e) => e.message,
            'message',
            contains('No playable source'),
          ),
        ),
      );
    });

    test('resolves a torrent once the proxy serves bytes', () async {
      final probed = <Uri>[];
      var probes = 0;
      final statuses = <String>[];
      String? requestedTorrentId;
      var proxyPort = 0;

      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => true,
        addTorrent: (magnet) async => 'torrent-1',
        startProxy: (port) async {
          proxyPort = 41234;
          return 41234;
        },
        getStreamUrl: (torrentId) async {
          requestedTorrentId = torrentId;
          return 'http://127.0.0.1:41234/stream/$torrentId';
        },
        probeStream: (uri) async {
          probed.add(uri);
          probes++;
          // Not ready on the first two attempts, like a cold swarm.
          return probes >= 3;
        },
        readinessTimeout: const Duration(seconds: 2),
        pollInterval: const Duration(milliseconds: 5),
      );

      final source = await resolver.resolve(
        magnetLink: 'magnet:?xt=urn:btih:abc',
        onStatus: statuses.add,
      );

      expect(proxyPort, 41234);
      expect(requestedTorrentId, 'torrent-1');
      expect(source.kind, PlaybackKind.torrent);
      expect(source.torrentId, 'torrent-1');
      expect(source.uri.toString(), 'http://127.0.0.1:41234/stream/torrent-1');
      expect(probes, 3);
      expect(probed.first.port, 41234);
      expect(statuses, contains('Connecting to peers...'));
      expect(statuses, contains('Starting playback...'));
    });

    test('retries getStreamUrl while the proxy is still booting', () async {
      var urlCalls = 0;
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => true,
        addTorrent: (_) async => 'torrent-2',
        startProxy: (_) async => 8090,
        getStreamUrl: (_) async {
          urlCalls++;
          return urlCalls >= 2 ? 'http://127.0.0.1:8090/stream/torrent-2' : null;
        },
        probeStream: (_) async => true,
        readinessTimeout: const Duration(seconds: 2),
        pollInterval: const Duration(milliseconds: 5),
      );

      final source = await resolver.resolve(magnetLink: 'magnet:?xt=urn:btih:def');

      expect(urlCalls, 2);
      expect(source.torrentId, 'torrent-2');
    });

    test('fails when the torrent engine is unavailable', () async {
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => false,
      );

      await expectLater(
        resolver.resolve(magnetLink: 'magnet:?xt=urn:btih:abc'),
        throwsA(
          isA<PlaybackException>().having(
            (e) => e.message,
            'message',
            contains('unavailable'),
          ),
        ),
      );
    });

    test('fails when the torrent cannot be added', () async {
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => true,
        addTorrent: (_) async => null,
      );

      await expectLater(
        resolver.resolve(magnetLink: 'magnet:?xt=urn:btih:abc'),
        throwsA(
          isA<PlaybackException>().having(
            (e) => e.message,
            'message',
            contains('could not be added'),
          ),
        ),
      );
    });

    test('fails when the local proxy does not start', () async {
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => true,
        addTorrent: (_) async => 'torrent-3',
        startProxy: (_) async => 0,
      );

      await expectLater(
        resolver.resolve(magnetLink: 'magnet:?xt=urn:btih:abc'),
        throwsA(
          isA<PlaybackException>().having(
            (e) => e.message,
            'message',
            contains('did not start'),
          ),
        ),
      );
    });

    test('times out with a retryable message when no peers respond', () async {
      final resolver = PlaybackSourceResolver(
        initializeEngine: () async => true,
        addTorrent: (_) async => 'torrent-4',
        startProxy: (_) async => 8091,
        getStreamUrl: (_) async => 'http://127.0.0.1:8091/stream/torrent-4',
        probeStream: (_) async => false,
        readinessTimeout: const Duration(milliseconds: 60),
        pollInterval: const Duration(milliseconds: 10),
      );

      await expectLater(
        resolver.resolve(magnetLink: 'magnet:?xt=urn:btih:abc'),
        throwsA(
          isA<PlaybackException>().having(
            (e) => e.message,
            'message',
            contains('No peers responded'),
          ),
        ),
      );
    });
  });
}
