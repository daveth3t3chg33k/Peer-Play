import 'dart:async';
import 'torrent_channel.dart';

/// High-level torrent service that manages torrent lifecycle and streaming.
class TorrentService {
  static TorrentService? _instance;
  static TorrentService get instance => _instance ??= TorrentService._();
  TorrentService._();

  bool _initialized = false;
  String? _currentTorrentId;
  Timer? _statusPollTimer;
  final _statusController = StreamController<TorrentStatusInfo>.broadcast();

  /// Stream of torrent status updates while downloading.
  Stream<TorrentStatusInfo> get statusStream => _statusController.stream;

  /// Current torrent ID being streamed.
  String? get currentTorrentId => _currentTorrentId;

  /// Initialize the torrent engine.
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await TorrentChannel.initialize();
    return _initialized;
  }

  /// Add a torrent and start downloading. Returns the torrent ID.
  Future<String?> startTorrent(String magnetLink) async {
    if (!_initialized) await initialize();

    final torrentId = await TorrentChannel.addTorrent(magnetLink);
    if (torrentId == null) return null;

    _currentTorrentId = torrentId;

    // Start polling for status updates every 2 seconds
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());

    return torrentId;
  }

  /// Poll the current torrent status and push to stream.
  Future<void> _pollStatus() async {
    if (_currentTorrentId == null) return;
    final status = await TorrentChannel.getTorrentStatus(_currentTorrentId!);
    if (status != null && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Get the local HTTP stream URL for the current torrent.
  Future<String?> getStreamUrl() async {
    if (_currentTorrentId == null) return null;
    return TorrentChannel.getStreamUrl(_currentTorrentId!);
  }

  /// Stop the current torrent and clean up.
  Future<void> stopCurrent() async {
    _statusPollTimer?.cancel();
    if (_currentTorrentId != null) {
      await TorrentChannel.removeTorrent(_currentTorrentId!);
      _currentTorrentId = null;
    }
  }

  /// Pause all downloads.
  Future<void> pauseAll() async {
    await TorrentChannel.pauseAll();
    _statusPollTimer?.cancel();
  }

  /// Resume all downloads.
  Future<void> resumeAll() async {
    await TorrentChannel.resumeAll();
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
  }

  /// Dispose the engine.
  Future<void> dispose() async {
    _statusPollTimer?.cancel();
    await TorrentChannel.dispose();
    await _statusController.close();
    _initialized = false;
    _instance = null;
  }
}
