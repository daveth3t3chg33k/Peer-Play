import 'dart:async';
import 'package:flutter/services.dart';

/// Status information about an active torrent.
class TorrentStatusInfo {
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int peerCount;
  final int fileSize;
  final String state;

  TorrentStatusInfo({
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.peerCount,
    required this.fileSize,
    required this.state,
  });

  factory TorrentStatusInfo.fromMap(Map<dynamic, dynamic> map) {
    int asInt(dynamic value) => value is num ? value.toInt() : 0;
    return TorrentStatusInfo(
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: asInt(map['download_speed']),
      uploadSpeed: asInt(map['upload_speed']),
      peerCount: asInt(map['peer_count']),
      fileSize: asInt(map['file_size']),
      state: map['state']?.toString() ?? 'unknown',
    );
  }

  /// Progress as a 0..1 fraction, clamped so bad native values cannot break
  /// the progress indicator.
  double get progressFraction => (progress.isFinite ? progress / 100 : 0.0).clamp(0.0, 1.0);

  /// Short human-readable state, stripped of UniFFI's Kotlin `toString()`
  /// decoration (e.g. `Downloading(progressPercent=12.5)`).
  String get stateLabel {
    final name = state.split('(').first.trim();
    switch (name) {
      case 'Downloading':
        return 'Downloading';
      case 'DownloadingMetadata':
        return 'Finding peers';
      case 'Streaming':
        return 'Streaming';
      case 'Completed':
        return 'Ready';
      case 'Paused':
        return 'Paused';
      case 'Error':
        return 'Engine error';
      case 'unknown':
      case 'stub':
      case '':
        return '';
      default:
        return name;
    }
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get downloadSpeedFormatted {
    if (downloadSpeed < 1024) return '$downloadSpeed B/s';
    if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

/// Platform channel bridge for the native Rust torrent engine.
///
/// Communicates with TorrentModule.kt on Android via MethodChannel.
class TorrentChannel {
  static const _channel = MethodChannel('com.peerplay/torrent');

  /// Initialize the torrent engine.
  ///
  /// When [downloadDir] is null the native side picks an app-private directory
  /// (`context.filesDir/torrents`). Do not default to external storage here:
  /// `/storage/emulated/0/...` is not writable under Android's scoped storage,
  /// so the engine could not create files and every stream request 404'd.
  static Future<bool> initialize({String? downloadDir}) async {
    try {
      await _channel.invokeMethod('initialize', <String, dynamic>{
        if (downloadDir != null) 'download_dir': downloadDir,
      });
      return true;
    } catch (e) {
      print('[TorrentChannel] initialize failed: $e');
      return false;
    }
  }

  /// Add a torrent by magnet link. Returns a torrent handle ID, or null on failure.
  static Future<String?> addTorrent(String magnetLink) async {
    try {
      final result = await _channel.invokeMethod('add_torrent', {
        'magnet_link': magnetLink,
      });
      return result as String?;
    } catch (e) {
      print('[TorrentChannel] addTorrent failed: $e');
      return null;
    }
  }

  /// Start streaming a specific file index from a torrent.
  /// Returns the local HTTP proxy URL (e.g. http://127.0.0.1:8090/stream/0).
  static Future<String?> startStream(String torrentId, int fileIndex) async {
    try {
      final result = await _channel.invokeMethod('start_stream', {
        'torrent_id': torrentId,
        'file_index': fileIndex,
      });
      return result as String?;
    } catch (e) {
      print('[TorrentChannel] startStream failed: $e');
      return null;
    }
  }

  /// Start the local HTTP proxy server. Returns the port, or 0 on failure.
  static Future<int> startProxy(int port) async {
    try {
      final result = await _channel.invokeMethod('start_proxy', {
        'port': port,
      });
      return result as int;
    } catch (e) {
      print('[TorrentChannel] startProxy failed: $e');
      return 0;
    }
  }

  /// Get the streaming URL for a torrent.
  static Future<String?> getStreamUrl(String torrentId) async {
    try {
      final result = await _channel.invokeMethod('get_stream_url', {
        'torrent_id': torrentId,
      });
      return result as String?;
    } catch (e) {
      print('[TorrentChannel] getStreamUrl failed: $e');
      return null;
    }
  }

  /// Get the status of a torrent.
  static Future<TorrentStatusInfo?> getTorrentStatus(String torrentId) async {
    try {
      final result = await _channel.invokeMethod('get_status', {
        'torrent_id': torrentId,
      });
      if (result is Map) {
        return TorrentStatusInfo.fromMap(result);
      }
      return null;
    } catch (e) {
      print('[TorrentChannel] getTorrentStatus failed: $e');
      return null;
    }
  }

  /// Pause a torrent.
  static Future<void> pauseTorrent(String torrentId) async {
    try {
      await _channel.invokeMethod('pause_torrent', {'torrent_id': torrentId});
    } catch (e) {
      print('[TorrentChannel] pauseTorrent failed: $e');
    }
  }

  /// Resume a torrent.
  static Future<void> resumeTorrent(String torrentId) async {
    try {
      await _channel.invokeMethod('resume_torrent', {'torrent_id': torrentId});
    } catch (e) {
      print('[TorrentChannel] resumeTorrent failed: $e');
    }
  }

  /// Pause all active torrents.
  static Future<void> pauseAll() async {
    try {
      await _channel.invokeMethod('pause_all');
    } catch (e) {
      print('[TorrentChannel] pauseAll failed: $e');
    }
  }

  /// Resume all paused torrents.
  static Future<void> resumeAll() async {
    try {
      await _channel.invokeMethod('resume_all');
    } catch (e) {
      print('[TorrentChannel] resumeAll failed: $e');
    }
  }

  /// Remove a torrent.
  static Future<void> removeTorrent(String torrentId, {bool deleteFiles = false}) async {
    try {
      await _channel.invokeMethod('remove_torrent', {
        'torrent_id': torrentId,
        'delete_files': deleteFiles,
      });
    } catch (e) {
      print('[TorrentChannel] removeTorrent failed: $e');
    }
  }

  /// Get the download progress for a torrent (0.0 - 100.0).
  static Future<double> getProgress(String torrentId) async {
    try {
      final result = await _channel.invokeMethod('get_progress', {
        'torrent_id': torrentId,
      });
      return (result as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// Dispose the torrent engine and clean up resources.
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      print('[TorrentChannel] dispose failed: $e');
    }
  }
}
