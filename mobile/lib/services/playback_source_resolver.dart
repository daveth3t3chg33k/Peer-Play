import 'dart:async';

import 'package:http/http.dart' as http;

import 'torrent_channel.dart';
import 'torrent_service.dart';

/// Where a [PlaybackSource]'s bytes come from.
enum PlaybackKind { torrent, direct }

/// A resolved, ready-to-open media URL.
class PlaybackSource {
  final Uri uri;
  final PlaybackKind kind;

  /// Torrent handle id when [kind] is [PlaybackKind.torrent].
  final String? torrentId;

  const PlaybackSource({required this.uri, required this.kind, this.torrentId});

  bool get isTorrent => kind == PlaybackKind.torrent;
}

/// A playback failure whose message is safe to show in the UI.
class PlaybackException implements Exception {
  final String message;

  const PlaybackException(this.message);

  @override
  String toString() => message;
}

typedef StatusCallback = void Function(String message);

/// Turns the player's metadata (a magnet link or a direct URL) into a stream
/// URL that is actually serving bytes.
///
/// The torrent path waits for the local proxy to answer a real range request
/// instead of sleeping for a fixed delay. ExoPlayer is only handed a URL once
/// the proxy has proven it can stream from the swarm, which avoids the
/// "source error" dead end players hit when they open a proxy that is still
/// resolving metadata.
class PlaybackSourceResolver {
  final Future<bool> Function() _initializeEngine;
  final Future<String?> Function(String magnetLink) _addTorrent;
  final Future<int> Function(int port) _startProxy;
  final Future<String?> Function(String torrentId) _getStreamUrl;
  final Future<bool> Function(Uri uri) _probeStream;

  /// How long to wait for the swarm/proxy to serve bytes before giving up.
  final Duration readinessTimeout;

  /// Delay between readiness attempts.
  final Duration pollInterval;

  PlaybackSourceResolver({
    Future<bool> Function()? initializeEngine,
    Future<String?> Function(String magnetLink)? addTorrent,
    Future<int> Function(int port)? startProxy,
    Future<String?> Function(String torrentId)? getStreamUrl,
    Future<bool> Function(Uri uri)? probeStream,
    this.readinessTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(milliseconds: 500),
  })  : _initializeEngine = initializeEngine ?? (() => TorrentService.instance.initialize()),
        _addTorrent = addTorrent ?? ((magnetLink) => TorrentService.instance.startTorrent(magnetLink)),
        _startProxy = startProxy ?? TorrentChannel.startProxy,
        _getStreamUrl = getStreamUrl ?? TorrentChannel.getStreamUrl,
        _probeStream = probeStream ?? probeStreamUrl;

  /// Resolve [magnetLink] or [directUrl] into a playable source.
  ///
  /// [onStatus] receives short, user-facing progress messages.
  /// Throws [PlaybackException] with a readable reason on failure.
  Future<PlaybackSource> resolve({
    String? magnetLink,
    String? directUrl,
    StatusCallback? onStatus,
  }) async {
    final magnet = _clean(magnetLink);
    if (magnet != null) {
      return _resolveTorrent(magnet, onStatus);
    }

    final direct = _clean(directUrl);
    if (direct != null) {
      final uri = Uri.tryParse(direct);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw const PlaybackException('This title has an invalid stream URL.');
      }
      onStatus?.call('Opening stream...');
      return PlaybackSource(uri: uri, kind: PlaybackKind.direct);
    }

    throw const PlaybackException(
      'No playable source is available for this title yet.',
    );
  }

  Future<PlaybackSource> _resolveTorrent(String magnet, StatusCallback? onStatus) async {
    onStatus?.call('Starting torrent engine...');
    bool engineReady;
    try {
      engineReady = await _initializeEngine();
    } catch (e) {
      throw PlaybackException('Could not start the torrent engine ($e).');
    }
    if (!engineReady) {
      throw const PlaybackException(
        'The torrent engine is unavailable on this device.',
      );
    }

    onStatus?.call('Finding the torrent...');
    final String? torrentId;
    try {
      torrentId = await _addTorrent(magnet);
    } catch (e) {
      throw PlaybackException('Could not add this torrent ($e).');
    }
    if (torrentId == null || torrentId.isEmpty) {
      throw const PlaybackException('This torrent could not be added.');
    }

    onStatus?.call('Starting the local stream...');
    int port;
    try {
      port = await _startProxy(0);
    } catch (e) {
      throw PlaybackException('Could not start the local stream server ($e).');
    }
    if (port == 0) {
      throw const PlaybackException('The local stream server did not start.');
    }

    return _waitForStream(torrentId, onStatus);
  }

  Future<PlaybackSource> _waitForStream(String torrentId, StatusCallback? onStatus) async {
    final deadline = DateTime.now().add(readinessTimeout);
    final started = DateTime.now();
    var attempts = 0;

    while (DateTime.now().isBefore(deadline)) {
      attempts++;
      final url = await _getStreamUrl(torrentId);
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && await _probeStream(uri)) {
          onStatus?.call('Starting playback...');
          return PlaybackSource(
            uri: uri,
            kind: PlaybackKind.torrent,
            torrentId: torrentId,
          );
        }
      }

      final elapsed = DateTime.now().difference(started).inSeconds;
      onStatus?.call(
        attempts == 1
            ? 'Connecting to peers...'
            : 'Buffering from peers... (${elapsed}s)',
      );
      await Future<void>.delayed(pollInterval);
    }

    throw const PlaybackException(
      'No peers responded in time. Check your connection and try again.',
    );
  }

  /// Issues a small ranged GET to confirm the proxy is serving real bytes.
  static Future<bool> probeStreamUrl(Uri uri) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['Range'] = 'bytes=0-1023';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 5));
      // Drain the (at most 1 KiB) body so the connection can be reused/closed.
      await response.stream.drain<void>();
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
