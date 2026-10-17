import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/auth_service.dart';

/// Movie card — displays real poster image with title, year, and bookmark toggle.
/// When [bookmarkedIds] is provided, shows a heart icon toggle on the poster.
class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Set<String>? bookmarkedIds;
  final VoidCallback? onBookmarkChanged;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
    this.width,
    this.height,
    this.bookmarkedIds,
    this.onBookmarkChanged,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.bookmarkedIds?.contains(widget.movie.id) ?? false;
  }

  @override
  void didUpdateWidget(MovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isBookmarked = widget.bookmarkedIds?.contains(widget.movie.id) ?? false;
  }

  Future<void> _toggleBookmark() async {
    final isAuth = await AuthService.isAuthenticated();
    if (!isAuth) {
      _showLoginPrompt();
      return;
    }

    final wasBookmarked = _isBookmarked;
    setState(() => _isBookmarked = !_isBookmarked);

    bool success;
    if (wasBookmarked) {
      success = await MovieService.removeBookmark(widget.movie.id);
    } else {
      success = await MovieService.addBookmark(widget.movie.id);
    }

    if (!success && mounted) {
      setState(() => _isBookmarked = wasBookmarked);
    }

    widget.onBookmarkChanged?.call();
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rMd)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to bookmark',
              style: TextStyle(fontSize: AppTheme.bodyLg, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create an account to save movies to your list and sync across devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Sign In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.width ?? 130;
    final cardHeight = widget.height ?? 195;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Stack(
            children: [
              Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.rPoster),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.movie.posterUrl.trim().isNotEmpty && widget.movie.posterUrl.trim() != ' '
                    ? Image.network(
                        widget.movie.posterUrl.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),

              // Bookmark heart icon — top-right corner
              if (widget.bookmarkedIds != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _toggleBookmark,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isBookmarked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: _isBookmarked ? AppTheme.primary : Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Title
          SizedBox(
            width: cardWidth,
            child: Text(
              widget.movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTheme.small,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          // Year
          if (widget.movie.releaseYear > 0)
            Text(
              '${widget.movie.releaseYear}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          widget.movie.title.isNotEmpty ? widget.movie.title.substring(0, 1.clamp(0, widget.movie.title.length)) : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
