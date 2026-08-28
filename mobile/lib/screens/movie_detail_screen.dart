import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;
  bool _loading = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    try {
      final movie = await MovieService.getMovie(widget.movieId);
      setState(() { _movie = movie; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    final movie = _movie;
    if (movie == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: Text('Movie not found', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: sw * 0.65,
            pinned: false,
            backgroundColor: AppTheme.surfaceLight,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.overlay,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: AppTheme.text, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.surfaceLight,
                child: Center(
                  child: Text(
                    movie.initial,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryLight.withOpacity(0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingBase),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    style: const TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),

                  // Meta row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: AppTheme.accentAmber),
                      const SizedBox(width: 4),
                      Text(movie.rating.toStringAsFixed(1), style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                      const Text(' · ', style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.fontSizeBody)),
                      Text(movie.releaseYear.toString(), style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                      const Text(' · ', style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.fontSizeBody)),
                      const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(movie.durationFormatted, style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingBase),

                  // Genres
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingSm,
                    children: movie.genres.map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase, vertical: AppTheme.spacingXs + 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(g, style: const TextStyle(fontSize: AppTheme.fontSizeSmall, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
                    )).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/player', arguments: {'movieId': movie.id, 'title': movie.title}),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeBodyLarge)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd + 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      _buildIconAction(Icons.download_rounded, false, null),
                      const SizedBox(width: AppTheme.spacingSm),
                      _buildIconAction(
                        Icons.bookmark_rounded,
                        _isBookmarked,
                        () => setState(() => _isBookmarked = !_isBookmarked),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      _buildIconAction(Icons.share_rounded, false, null),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXl),

                  // Synopsis
                  const Text('SYNOPSIS', style: TextStyle(fontSize: AppTheme.fontSizeCaption, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1)),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(movie.description, style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.textSecondary, height: 1.6)),
                  const SizedBox(height: AppTheme.spacingXl),

                  // Sources
                  if (movie.sources != null && movie.sources!.isNotEmpty) ...[
                    const Text('Available Quality', style: TextStyle(fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    const SizedBox(height: AppTheme.spacingMd),
                    ...movie.sources!.map((s) => GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/player', arguments: {'movieId': movie.id, 'title': movie.title}),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                        padding: const EdgeInsets.all(AppTheme.spacingBase),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.movie_rounded, size: 16, color: AppTheme.primary),
                                const SizedBox(width: AppTheme.spacingSm),
                                Text(s.quality, style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                              ],
                            ),
                            Text(s.fileSizeMB, style: const TextStyle(fontSize: AppTheme.fontSizeSmall, color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                    )),
                  ],

                  // Subtitles
                  if (movie.subtitles != null && movie.subtitles!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXl),
                    const Text('Subtitles', style: TextStyle(fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    const SizedBox(height: AppTheme.spacingMd),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: movie.subtitles!.map((sub) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase, vertical: AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(sub.languageName, style: const TextStyle(fontSize: AppTheme.fontSizeSmall, color: AppTheme.textSecondary)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction(IconData icon, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGlow : AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
        ),
        child: Icon(icon, size: 20, color: active ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}
