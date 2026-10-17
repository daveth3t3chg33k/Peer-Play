// On-device end-to-end test for the P2P streaming path.
//
// Drives the real UI (Search -> detail -> Play) and then asserts that the
// native Rust torrent engine resolved the magnet, started the local HTTP proxy,
// that ExoPlayer initialised a video from it and that playback actually
// advances.
//
// Requires a running backend (the catalogue must contain the "Sintel" entry
// seeded by server/migrations/007_real_stream_sources.sql) and a network
// connection so the swarm can be reached.
//
// Run with:  flutter test integration_test/stream_playback_test.dart -d <device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

import 'package:peerplay/main.dart' as app;
import 'package:peerplay/services/torrent_channel.dart';
import 'package:peerplay/services/torrent_service.dart';
import 'package:peerplay/widgets/movie_card.dart';

/// Pumps the live binding until [condition] holds, or [timeout] elapses.
/// Uses real delays because the app performs genuine network work.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
    if (condition()) return true;
  }
  await tester.pump();
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays a real movie through the P2P torrent pipeline',
      (tester) async {
    await app.main();
    final appReady = await _pumpUntil(
      tester,
      () => find.byType(BottomNavigationBar).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );
    expect(appReady, isTrue, reason: 'the app shell should render');

    // 1. Search for a title that has a real seeded magnet.
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byIcon(Icons.search_rounded),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(find.byType(TextField), 'Sintel');

    final gotResults = await _pumpUntil(
      tester,
      () => find.byType(MovieCard).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    expect(gotResults, isTrue,
        reason: 'search for "Sintel" should return the seeded catalogue entry. '
            'Is the backend running on 10.0.2.2:8080 and are the migrations applied?');

    // 2. Open the detail screen and make sure the seeded source is present
    //    before starting playback, so a data problem is reported clearly.
    await tester.tap(find.byType(MovieCard).first);
    final onDetail = await _pumpUntil(
      tester,
      () => find.byKey(const Key('movie-play-button')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    );
    expect(onDetail, isTrue, reason: 'detail screen should show a Play button');
    expect(find.text('1080p'), findsWidgets,
        reason: 'migration 007 should expose a 1080p magnet for Sintel');

    await tester.tap(find.byKey(const Key('movie-play-button')));

    // 3. The player only renders the VideoPlayer widget once the controller is
    //    initialised, i.e. ExoPlayer actually pulled decodable video from the
    //    local torrent proxy. Fail fast if the player reports an error.
    var playerErrored = false;
    final initialised = await _pumpUntil(
      tester,
      () {
        if (find.byKey(const Key('playback-error-icon')).evaluate().isNotEmpty) {
          playerErrored = true;
          return true;
        }
        return find.byType(VideoPlayer).evaluate().isNotEmpty;
      },
      timeout: const Duration(seconds: 110),
    );

    final torrentId = TorrentService.instance.currentTorrentId;
    final status =
        torrentId == null ? null : await TorrentChannel.getTorrentStatus(torrentId);
    final streamUrl =
        torrentId == null ? null : await TorrentChannel.getStreamUrl(torrentId);

    // Surface the diagnostics in the test output so failures are debuggable.
    // ignore: avoid_print
    print('[e2e] torrentId=$torrentId streamUrl=$streamUrl '
        'status=${status?.state} peers=${status?.peerCount} '
        'progress=${status?.progress} speed=${status?.downloadSpeed}');

    if (playerErrored) {
      final message = find.byKey(const Key('playback-error-message'));
      final text = message.evaluate().isEmpty
          ? 'unknown'
          : tester.widget<Text>(message.first).data;
      fail('player reported a source error: $text');
    }

    expect(torrentId, isNotNull,
        reason: 'the torrent engine should have added the magnet');
    expect(streamUrl, isNotNull,
        reason: 'the local streaming proxy should have started');
    expect(streamUrl, contains('http://127.0.0.1:'));
    expect(initialised, isTrue,
        reason: 'ExoPlayer should have initialised the video from the proxy');

    expect(find.byKey(const Key('player-p2p-badge')), findsOneWidget,
        reason: 'the player should flag torrent playback');

    // 4. Initialisation alone is not playback: wait for the position to move.
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    final advanced = await _pumpUntil(
      tester,
      () => controller.value.position > Duration.zero,
      timeout: const Duration(seconds: 30),
    );
    // ignore: avoid_print
    print('[e2e] position=${controller.value.position} '
        'duration=${controller.value.duration}');

    expect(controller.value.hasError, isFalse,
        reason: 'controller error: ${controller.value.errorDescription}');
    expect(advanced, isTrue,
        reason: 'playback should advance past 0s once bytes are flowing');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
