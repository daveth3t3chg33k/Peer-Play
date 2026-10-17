import 'dart:async';

import 'torrent_channel.dart';

/// High-level torrent service that manages torrent lifecycle and streaming.
class TorrentService {
  static TorrentService? _instance;
  static TorrentService get instance => _instance ??= TorrentService._();
  TorrentService._();

  bool _initialized = false;
  Future<bool>? _initializing;
  String? _currentTorrentId;
  String? _currentMagnet;
  Timer? _statusPollTimer;
  final _statusController = StreamController<TorrentStatusInfo>.broadcast();

  /// Stream of torrent status updates while downloading.
  Stream<TorrentStatusInfo> get statusStream => _statusController.stream;

  /// Current torrent ID being streamed.
  String? get currentTorrentId => _currentTorrentId;

  /// Current magnet link being streamed.
  String? get currentMagnet => _currentMagnet;

  /// Initialize the torrent engine. Concurrent callers share one attempt.
  Future<bool> initialize() {
    if (_initialized) return Future<bool>.value(true);
    return _initializing ??= _initializeEngine().whenComplete(() {
      _initializing = null;
    });
  }

  Future<bool> _initializeEngine() async {
    _initialized = await TorrentChannel.initialize();
    return _initialized;
  }

  /// Add a torrent and start downloading. Returns the torrent ID.
  ///
  /// Re-adding the magnet that is already active (retry, back to player)
  /// reuses the existing handle instead of creating a duplicate download.
  Future<String?> startTorrent(String magnetLink) async {
    if (!_initialized && !await initialize()) return null;

    if (_currentMagnet == magnetLink && _currentTorrentId != null) {
      _startStatusPolling();
      return _currentTorrentId;
    }

    final torrentId = await TorrentChannel.addTorrent(magnetLink);
    if (torrentId == null) return null;

    _currentTorrentId = torrentId;
    _currentMagnet = magnetLink;
    _startStatusPolling();

    return torrentId;
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    // Push one update immediately so the UI does not wait a full interval.
    unawaited(_pollStatus());
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(),
    );
  }

  /// Stop pushing status updates without touching the torrent itself.
  ///
  /// Used when the player is closed: the transfer keeps running in the
  /// background so reopening the title can resume from existing pieces.
  void stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  /// Poll the current torrent status and push to stream.
  Future<void> _pollStatus() async {
    final torrentId = _currentTorrentId;
    if (torrentId == null) return;
    final status = await TorrentChannel.getTorrentStatus(torrentId);
    if (status != null && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Get the local HTTP stream URL for the current (or given) torrent.
  Future<String?> getStreamUrl({String? torrentId}) async {
    final id = torrentId ?? _currentTorrentId;
    if (id == null) return null;
    return TorrentChannel.getStreamUrl(id);
  }

  /// Stop the current torrent and clean up.
  Future<void> stopCurrent() async {
    stopStatusPolling();
    final torrentId = _currentTorrentId;
    _currentTorrentId = null;
    _currentMagnet = null;
    if (torrentId != null) {
      await TorrentChannel.removeTorrent(torrentId);
    }
  }

  /// Pause all downloads.
  Future<void> pauseAll() async {
    await TorrentChannel.pauseAll();
    stopStatusPolling();
  }

  /// Resume all downloads.
  Future<void> resumeAll() async {
    await TorrentChannel.resumeAll();
    _startStatusPolling();
  }

  /// Dispose the engine.
  Future<void> dispose() async {
    stopStatusPolling();
    _currentTorrentId = null;
    _currentMagnet = null;
    await TorrentChannel.dispose();
    await _statusController.close();
    _initialized = false;
    _instance = null;
  }
}
