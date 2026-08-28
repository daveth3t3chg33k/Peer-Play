import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppColors {
  AppColors._();
}

class MovieCard extends StatelessWidget {
  final String title;
  final String initial;
  final double rating;
  final int releaseYear;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.title,
    required this.initial,
    this.rating = 0,
    this.releaseYear = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster placeholder
          Container(
            width: 130,
            height: 195,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusPoster),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryLight.withOpacity(0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
          if (rating > 0 || releaseYear > 0)
            Row(
              children: [
                if (rating > 0) ...[
                  const Icon(Icons.star_rounded, size: 12, color: AppTheme.accentAmber),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber),
                  ),
                ],
                if (rating > 0 && releaseYear > 0) const SizedBox(width: 4),
                if (releaseYear > 0)
                  Text(
                    releaseYear.toString(),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
