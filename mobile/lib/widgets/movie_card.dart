import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';

/// Movie card — displays real poster image with title and year
class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = width ?? 130;
    final cardHeight = height ?? 195;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.rPoster),
            ),
            clipBehavior: Clip.antiAlias,
            child: movie.posterUrl.trim().isNotEmpty && movie.posterUrl.trim() != ' '
                ? Image.network(
                    movie.posterUrl.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(height: 6),
          // Title
          SizedBox(
            width: cardWidth,
            child: Text(
              movie.title,
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
          if (movie.releaseYear > 0)
            Text(
              '${movie.releaseYear}',
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
          movie.title.isNotEmpty ? movie.title.substring(0, 1.clamp(0, movie.title.length)) : '?',
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
