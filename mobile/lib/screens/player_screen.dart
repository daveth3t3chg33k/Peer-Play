import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/theme.dart';
import '../services/movie_service.dart';
import '../services/torrent_channel.dart';
import '../services/torrent_service.dart';
import '../services/auth_service.dart';

/// Video player screen — Netflix-style controls with torrent streaming support.
///
/// When a magnetLink is provided, the player downloads via P2P and streams
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

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _buffering = false;
  bool _loading = true;
  bool _error = false;
  String _statusMessage = 'Preparing...';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  TorrentStatusInfo? _torrentStatus;
  StreamSubscription<TorrentStatusInfo>? _torrentSub;
  Timer? _progressTimer;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _checkAuth();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    try {
      String? streamUrl;

      if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
        // Torrent streaming path
        setState(() => _statusMessage = 'Connecting to peers...');

        final initialized = await TorrentService.instance.initialize();
        if (!initialized) {
          setState(() {
            _error = true;
            _statusMessage = 'Failed to initialize torrent engine';
          });
          return;
        }

        final torrentId = await TorrentService.instance.startTorrent(widget.magnetLink!);
        if (torrentId == null) {
          setState(() {
            _error = true;
            _statusMessage = 'Failed to add torrent';
          });
          return;
        }

        // Listen to torrent status updates
        _torrentSub = TorrentService.instance.statusStream.listen((status) {
          if (mounted) {
            setState(() {
              _torrentStatus = status;
              _statusMessage = 'Downloading ${status.fileSizeFormatted} '
                  '(${status.downloadSpeedFormatted}) '
                  '${status.progress.toStringAsFixed(0)}%';
            });
          }
        });

        // Start local proxy
        final proxyPort = await TorrentChannel.startProxy(0); // 0 = auto-select port
        if (proxyPort == 0) {
          setState(() {
            _error = true;
            _statusMessage = 'Failed to start proxy server';
          });
          return;
        }

        // Wait a bit for the torrent to resolve metadata and start downloading
        await Future.delayed(const Duration(seconds: 3));

        streamUrl = await TorrentService.instance.getStreamUrl();
        if (streamUrl == null) {
          setState(() {
            _error = true;
            _statusMessage = 'Stream URL not available yet';
          });
          return;
        }
      } else if (widget.directUrl != null && widget.directUrl!.isNotEmpty) {
        streamUrl = widget.directUrl!;
      } else {
        // Fallback demo
        streamUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      }

      // Initialize video player
      _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _duration = _controller!.value.duration;
              _loading = false;
            });
            _controller!.addListener(_onProgress);
            _controller!.play();
            _startProgressTracking();
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _error = true;
              _statusMessage = 'Failed to load video: $error';
            });
          }
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  void _onProgress() {
    if (!mounted || _controller == null) return;
    final v = _controller!.value;
    setState(() {
      _position = v.position;
      _buffering = v.isBuffering;
    });
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
    if (!_isAuthenticated || _controller == null) return;
    final seconds = _position.inSeconds;
    final total = _duration.inSeconds;
    final completed = total > 0 && seconds >= total - 5;
    MovieService.updateWatchProgress(
      widget.movieId,
      seconds,
      completed: completed,
    );
  }

  @override
  void dispose() {
    _sendProgressUpdate(); // Final progress update on exit
    _progressTimer?.cancel();
    _controller?.removeListener(_onProgress);
    _controller?.dispose();
    _torrentSub?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
    _showControls();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_controller == null) return;
          if (!_controlsVisible) {
            _showControls();
          } else {
            setState(() => _controlsVisible = false);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_error)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = false;
                            _loading = true;
                            _statusMessage = 'Retrying...';
                          });
                          _startPlayback();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Loading / buffering / torrent status
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loading || _buffering) ...[
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (_torrentStatus != null) ...[
                      const SizedBox(height: 12),
                      // Torrent download progress bar
                      SizedBox(
                        width: 200,
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: (_torrentStatus!.progress / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              color: AppTheme.primary,
                              minHeight: 3,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_torrentStatus!.peerCount} peers | '
                              '${_torrentStatus!.downloadSpeedFormatted}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Controls overlay
            if (_controlsVisible && _controller != null && _controller!.value.isInitialized)
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
                              if (_torrentStatus != null)
                                Container(
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

                        // Center play
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
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
                                        value: progress.clamp(0.0, 1.0),
                                        onChanged: (v) {
                                          _controller!.seekTo(
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
