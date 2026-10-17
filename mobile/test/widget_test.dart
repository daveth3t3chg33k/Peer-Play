import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peerplay/config/theme.dart';
import 'package:peerplay/services/torrent_channel.dart';
import 'package:peerplay/widgets/playback_status_panel.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(backgroundColor: Colors.black, body: child),
  );
}

void main() {
  group('PlaybackStatusPanel', () {
    testWidgets('shows a spinner and the current status message', (tester) async {
      await tester.pumpWidget(_host(
        const PlaybackStatusPanel(message: 'Connecting to peers...', busy: true),
      ));

      expect(find.text('Connecting to peers...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('playback-error-icon')), findsNothing);
      expect(find.byKey(const Key('playback-retry')), findsNothing);
    });

    testWidgets('renders torrent progress, peers and speed', (tester) async {
      final status = TorrentStatusInfo(
        progress: 42.4,
        downloadSpeed: 1536 * 1024,
        uploadSpeed: 0,
        peerCount: 7,
        fileSize: 129302391,
        state: 'Downloading(progressPercent=42.4)',
      );

      await tester.pumpWidget(_host(
        PlaybackStatusPanel(
          message: 'Downloading 123.3 MB (1.5 MB/s)',
          busy: true,
          torrentStatus: status,
        ),
      ));

      expect(find.byKey(const Key('torrent-progress')), findsOneWidget);
      expect(find.text('42%  |  7 peers  |  1.5 MB/s'), findsOneWidget);
      expect(find.text('Downloading'), findsOneWidget);
    });

    testWidgets('error state shows the message and invokes retry/back',
        (tester) async {
      var retries = 0;
      var backs = 0;

      await tester.pumpWidget(_host(
        PlaybackStatusPanel(
          isError: true,
          message: 'No peers responded in time.',
          onRetry: () => retries++,
          onBack: () => backs++,
        ),
      ));

      expect(find.byKey(const Key('playback-error-icon')), findsOneWidget);
      expect(find.text('No peers responded in time.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('playback-retry')));
      await tester.tap(find.text('Back'));

      expect(retries, 1);
      expect(backs, 1);
    });
  });
}
