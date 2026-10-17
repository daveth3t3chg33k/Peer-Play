import 'package:flutter_test/flutter_test.dart';

import 'package:peerplay/services/torrent_channel.dart';

TorrentStatusInfo _status({
  double progress = 0,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  int peerCount = 0,
  int fileSize = 0,
  String state = 'unknown',
}) {
  return TorrentStatusInfo(
    progress: progress,
    downloadSpeed: downloadSpeed,
    uploadSpeed: uploadSpeed,
    peerCount: peerCount,
    fileSize: fileSize,
    state: state,
  );
}

void main() {
  group('TorrentStatusInfo.fromMap', () {
    test('parses the native status map', () {
      final status = TorrentStatusInfo.fromMap({
        'progress': 12.5,
        'download_speed': 2048,
        'upload_speed': 64,
        'peer_count': 3,
        'file_size': 129302391,
        'state': 'Downloading(progressPercent=12.5)',
      });

      expect(status.progress, 12.5);
      expect(status.downloadSpeed, 2048);
      expect(status.uploadSpeed, 64);
      expect(status.peerCount, 3);
      expect(status.fileSize, 129302391);
      expect(status.stateLabel, 'Downloading');
    });

    test('accepts integer and missing values without throwing', () {
      final status = TorrentStatusInfo.fromMap({'progress': 7});

      expect(status.progress, 7.0);
      expect(status.downloadSpeed, 0);
      expect(status.peerCount, 0);
      expect(status.state, 'unknown');
      expect(status.stateLabel, '');
    });
  });

  group('TorrentStatusInfo.progressFraction', () {
    test('converts percentage to a 0..1 fraction', () {
      expect(_status(progress: 0).progressFraction, 0);
      expect(_status(progress: 50).progressFraction, 0.5);
      expect(_status(progress: 100).progressFraction, 1);
    });

    test('clamps out-of-range native values', () {
      expect(_status(progress: 140).progressFraction, 1);
      expect(_status(progress: -20).progressFraction, 0);
      expect(_status(progress: double.nan).progressFraction, 0);
    });
  });

  group('formatting', () {
    test('formats file sizes', () {
      expect(_status(fileSize: 512).fileSizeFormatted, '512 B');
      expect(_status(fileSize: 2048).fileSizeFormatted, '2.0 KB');
      expect(_status(fileSize: 5 * 1024 * 1024).fileSizeFormatted, '5.0 MB');
      expect(
        _status(fileSize: 3 * 1024 * 1024 * 1024).fileSizeFormatted,
        '3.00 GB',
      );
    });

    test('formats download speed', () {
      expect(_status(downloadSpeed: 900).downloadSpeedFormatted, '900 B/s');
      expect(_status(downloadSpeed: 2048).downloadSpeedFormatted, '2.0 KB/s');
      expect(
        _status(downloadSpeed: 3 * 1024 * 1024).downloadSpeedFormatted,
        '3.0 MB/s',
      );
    });
  });

  group('stateLabel', () {
    test('maps native enum strings to short labels', () {
      expect(_status(state: 'DownloadingMetadata').stateLabel, 'Finding peers');
      expect(_status(state: 'Completed').stateLabel, 'Ready');
      expect(_status(state: 'Paused').stateLabel, 'Paused');
      expect(_status(state: 'Error(message=boom)').stateLabel, 'Engine error');
      expect(_status(state: 'Streaming').stateLabel, 'Streaming');
      expect(_status(state: 'stub').stateLabel, '');
    });
  });
}
