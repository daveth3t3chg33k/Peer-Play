import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/movie_service.dart';
import '../services/playback_source_resolver.dart';
import '../services/torrent_channel.dart';
import '../services/torrent_service.dart';
import '../widgets/playback_status_panel.dart';

/// Video player screen — Netflix-style controls with torrent streaming support.
///
/// When a magnet link is provided, the player downloads via P2P and streams
/// through the local proxy. When only a URL is provided, it plays directly.
class PlayerScreen extends StatefulWidget {
  final String movieId;
  final String title;
  final String? magnetLink;
  final String? directUrl;

  const PlayerScreen({
    super.key,
    required this.movieId,
    required this.title,
    this.magnetLink,
    this.directUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _buffering = false;
  bool _loading = true;
  bool _error = false;
  bool _starting = false;
  bool _isTorrent = false;
  String _statusMessage = 'Preparing...';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  TorrentStatusInfo? _torrentStatus;
  StreamSubscription<TorrentStatusInfo>? _torrentSub;
  Timer? _progressTimer;
  Timer? _hideControlsTimer;
  bool _isAuthenticated = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(WakelockPlus.enable());
    _checkAuth();
    _startPlayback();
  }

  /// Resolve the configured source and attach the video controller.
  ///
  /// Safe to call again from Retry: previous controllers, listeners and timers
  /// are torn down first, and concurrent starts are ignored.
  Future<void> _startPlayback() async {
    if (_starting) return;
    _starting = true;

    try {
      await _teardownVideo();
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = false;
        _buffering = false;
        _torrentStatus = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _statusMessage = 'Preparing...';
      });

      _torrentSub ??= TorrentService.instance.statusStream.listen(_onTorrentStatus);

      final source = await PlaybackSourceResolver().resolve(
        magnetLink: widget.magnetLink,
        directUrl: widget.directUrl,
        onStatus: (message) {
          if (mounted) setState(() => _statusMessage = message);
        },
      );
      if (!mounted) return;

      _isTorrent = source.isTorrent;
      await _attachVideo(source.uri);
    } on PlaybackException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Playback failed: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _attachVideo(Uri uri) async {
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;

    try {
      await controller.initialize();
    } catch (e) {
      if (!identical(_controller, controller)) return;
      _controller = null;
      await controller.dispose();
      _fail('Failed to load video: $e');
      return;
    }

    // The screen can be popped while ExoPlayer is still preparing.
    if (!mounted || _disposed) {
      if (identical(_controller, controller)) _controller = null;
      await controller.dispose();
      return;
    }

    setState(() {
      _duration = controller.value.duration;
      _loading = false;
      _statusMessage = 'Preparing...';
    });
    controller.addListener(_onProgress);
    await controller.play();
    _startProgressTracking();
    _showControls();
  }

  void _onTorrentStatus(TorrentStatusInfo status) {
    if (!mounted) return;
    setState(() {
      _torrentStatus = status;
      // Only let download progress describe the wait; once video is playing
      // the player controls are the source of truth.
      if (_loading && !_error) {
        _statusMessage = 'Downloading ${status.fileSizeFormatted} '
            '(${status.downloadSpeedFormatted})';
      }
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = true;
      _loading = false;
      _buffering = false;
      _statusMessage = message;
    });
  }

  void _onProgress() {
    final controller = _controller;
    if (!mounted || controller == null) return;

    final value = controller.value;
    if (value.hasError) {
      _fail('Stream interrupted: ${value.errorDescription ?? 'unknown error'}');
      return;
    }

    // The controller notifies every frame; only rebuild when something the UI
    // actually renders changed.
    if (value.isBuffering != _buffering ||
        value.position.inSeconds != _position.inSeconds) {
      setState(() {
        _position = value.position;
        _buffering = value.isBuffering;
      });
    }
  }

  Future<void> _checkAuth() async {
    _isAuthenticated = await AuthService.isAuthenticated();
  }

  /// Send watch progress to the backend every 30 seconds.
  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendProgressUpdate();
    });
  }

  void _sendProgressUpdate() {
    if (!_isAuthenticated || widget.movieId.isEmpty) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final seconds = controller.value.position.inSeconds;
    final total = controller.value.duration.inSeconds;
    if (seconds <= 0) return;
    final completed = total > 0 && seconds >= total - 5;

    unawaited(MovieService.updateWatchProgress(
      widget.movieId,
      seconds,
      completed: completed,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
        _sendProgressUpdate();
        if (mounted) setState(() => _controlsVisible = true);
      }
    }
  }

  @override
  void dispose() {
    _sendProgressUpdate(); // Final progress update on exit
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onProgress);
    _controller?.dispose();
    _controller = null;
    _torrentSub?.cancel();
    _torrentSub = null;
    // Keep downloading for future playback, but stop the UI polling loop.
    TorrentService.instance.stopStatusPolling();
    unawaited(WakelockPlus.disable());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _teardownVideo() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onProgress);
      await controller.dispose();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
      _sendProgressUpdate();
    } else {
      controller.play();
    }
    _showControls();
  }

  void _seekBy(Duration offset) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final target = controller.value.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    controller.seekTo(clamped);
    setState(() => _position = clamped);
    _showControls();
  }

  void _showControls() {
    _hideControlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      final controller = _controller;
      if (mounted && controller != null && controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controller == null) return;
    if (!_controlsVisible) {
      _showControls();
    } else {
      _hideControlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  bool get _videoReady {
    final controller = _controller;
    return controller != null && controller.value.isInitialized;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady)
              Center(
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              )
            else if (_error)
              PlaybackStatusPanel(
                isError: true,
                message: _statusMessage,
                torrentStatus: _torrentStatus,
                onRetry: () => unawaited(_startPlayback()),
                onBack: () => Navigator.pop(context),
              )
            else
              PlaybackStatusPanel(
                busy: _loading || _buffering,
                message: _statusMessage,
                torrentStatus: _torrentStatus,
              ),

            // Buffering pill while playing with the controls hidden.
            if (_videoReady && _buffering && !_controlsVisible)
              const Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppTheme.xl),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // Controls overlay
            if (_controlsVisible && _videoReady)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      stops: [0, 0.2, 0.8, 1],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                              ),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTheme.bodyLg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Torrent indicator
                              if (_isTorrent || _torrentStatus != null)
                                Container(
                                  key: const Key('player-p2p-badge'),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'P2P',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Center transport
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const Key('player-skip-back'),
                              onPressed: () => _seekBy(const Duration(seconds: -10)),
                              iconSize: 30,
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: AppTheme.base),
                            GestureDetector(
                              key: const Key('player-play-pause'),
                              onTap: _togglePlay,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  controller!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.base),
                            IconButton(
                              key: const Key('player-skip-forward'),
                              onPressed: () => _seekBy(const Duration(seconds: 10)),
                              iconSize: 30,
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                            ),
                          ],
                        ),

                        // Bottom controls
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _fmt(_position),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: AppTheme.caption,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.sm),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: AppTheme.primary,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: AppTheme.primary,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        trackHeight: 2,
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      ),
                                      child: Slider(
                                        key: const Key('player-seek'),
                                        value: progress,
                                        onChanged: (v) {
                                          controller.seekTo(
                                            Duration(milliseconds: (v * _duration.inMilliseconds).toInt()),
                                          );
                                          _showControls();
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.sm),
                                  Text(
                                    _fmt(_duration),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: AppTheme.caption,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.sm),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
