import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/theme.dart';

/// Video player screen — Netflix-style controls
class PlayerScreen extends StatefulWidget {
  final String movieId;
  final String title;
  const PlayerScreen({super.key, required this.movieId, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _demoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  late VideoPlayerController _controller;
  bool _controlsVisible = true;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _controller = VideoPlayerController.networkUrl(Uri.parse(_demoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _duration = _controller.value.duration);
        _controller.addListener(_onProgress);
      });
  }

  void _onProgress() {
    if (!mounted) return;
    final v = _controller.value;
    setState(() { _position = v.position; _buffering = v.isBuffering; });
  }

  @override
  void dispose() {
    _controller.removeListener(_onProgress);
    _controller.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); });
    _showControls();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) setState(() => _controlsVisible = false);
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
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { if (!_controlsVisible) _showControls(); else setState(() => _controlsVisible = false); },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
                  : const CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2),
            ),

            if (_buffering)
              const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

            // Controls overlay
            if (_controlsVisible)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54],
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
                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22)),
                              Expanded(
                                child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: AppTheme.bodyLg, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                        // Center play
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                              child: Icon(_controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
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
                                  Text(_fmt(_position), style: const TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.caption)),
                                  const SizedBox(width: AppTheme.sm),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(activeTrackColor: AppTheme.primary, inactiveTrackColor: Colors.white24, thumbColor: AppTheme.primary, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2, overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)),
                                      child: Slider(value: progress.clamp(0.0, 1.0), onChanged: (v) { _controller.seekTo(Duration(milliseconds: (v * _duration.inMilliseconds).toInt())); _showControls(); }),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.sm),
                                  Text(_fmt(_duration), style: const TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.caption)),
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
