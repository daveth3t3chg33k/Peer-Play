import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/torrent_channel.dart';

/// Full-screen player state shown before video is ready or after a failure.
///
/// Kept free of player/torrent plumbing so it can be widget-tested directly.
class PlaybackStatusPanel extends StatelessWidget {
  final String message;
  final bool busy;
  final bool isError;
  final TorrentStatusInfo? torrentStatus;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const PlaybackStatusPanel({
    super.key,
    required this.message,
    this.busy = false,
    this.isError = false,
    this.torrentStatus,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          key: const Key('playback-status-panel'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isError)
              const Icon(
                Icons.error_outline_rounded,
                key: Key('playback-error-icon'),
                color: Colors.white54,
                size: 44,
              )
            else if (busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            const SizedBox(height: AppTheme.base),
            Text(
              message,
              key: Key(isError ? 'playback-error-message' : 'playback-status-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: AppTheme.body,
                height: 1.4,
              ),
            ),
            if (torrentStatus != null) ...[
              const SizedBox(height: AppTheme.base),
              _TorrentProgress(status: torrentStatus!),
            ],
            if (isError) ...[
              const SizedBox(height: AppTheme.xl),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  key: const Key('playback-retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
              if (onBack != null)
                TextButton(
                  onPressed: onBack,
                  child: const Text(
                    'Back',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TorrentProgress extends StatelessWidget {
  final TorrentStatusInfo status;

  const _TorrentProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final percent = (status.progressFraction * 100).toStringAsFixed(0);
    return SizedBox(
      key: const Key('torrent-progress'),
      width: 220,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.rXs),
            child: LinearProgressIndicator(
              value: status.progressFraction,
              backgroundColor: Colors.white24,
              color: AppTheme.primary,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            '$percent%  |  ${status.peerCount} peers  |  ${status.downloadSpeedFormatted}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: AppTheme.caption,
            ),
          ),
          if (status.stateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              status.stateLabel,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: AppTheme.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
