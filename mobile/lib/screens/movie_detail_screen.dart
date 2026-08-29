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

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    try {
      final movie = await MovieService.getMovie(widget.movieId);
      if (mounted) setState(() { _movie = movie; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    if (_loading) {
      return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2)));
    }

    final movie = _movie;
    if (movie == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background, leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context))),
        body: const Center(child: Text('Movie not found', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Backdrop
          SliverAppBar(
            expandedHeight: sw * 0.6,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  movie.backdropUrl.trim().isNotEmpty && movie.backdropUrl.trim() != ' '
                      ? Image.network(movie.backdropUrl.trim(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildBackdropPlaceholder(movie))
                      : _buildBackdropPlaceholder(movie),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0D0D0D), Color(0xFF0D0D0D)],
                        stops: [0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    style: const TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5, height: 1.1),
                  ),
                  const SizedBox(height: AppTheme.md),

                  // Meta row
                  Row(
                    children: [
                      if (movie.rating > 0) ...[
                        const Icon(Icons.star, size: 14, color: AppTheme.accentAmber),
                        const SizedBox(width: 4),
                        Text(movie.rating.toStringAsFixed(1), style: const TextStyle(fontSize: AppTheme.body, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                        const SizedBox(width: AppTheme.sm),
                      ],
                      Text('${movie.releaseYear}', style: const TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary)),
                      const SizedBox(width: AppTheme.sm),
                      Text(movie.durationFormatted, style: const TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.base),

                  // Genres
                  Wrap(
                    spacing: AppTheme.sm,
                    runSpacing: AppTheme.sm,
                    children: movie.genres.map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.rRound),
                      ),
                      child: Text(g, style: const TextStyle(fontSize: AppTheme.small, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                    )).toList(),
                  ),
                  const SizedBox(height: AppTheme.xl),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/player', arguments: {'movieId': movie.id, 'title': movie.title}),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      _buildIconAction(Icons.bookmark_outline_rounded, false, null),
                      const SizedBox(width: AppTheme.sm),
                      _buildIconAction(Icons.share_rounded, false, null),
                    ],
                  ),
                  const SizedBox(height: AppTheme.xl),

                  // Synopsis
                  Text(
                    'About',
                    style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    movie.description,
                    style: const TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary, height: 1.6),
                  ),

                  // Sources
                  if (movie.sources != null && movie.sources!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    const Text('Available Sources', style: TextStyle(fontSize: AppTheme.subtitle, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: AppTheme.md),
                    ...movie.sources!.map((s) => GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/player', arguments: {'movieId': movie.id, 'title': movie.title}),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.sm),
                        padding: const EdgeInsets.all(AppTheme.base),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.rMd)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.quality, style: const TextStyle(fontSize: AppTheme.bodyLg, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            Text(s.fileSizeMB, style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    )),
                  ],

                  // Subtitles
                  if (movie.subtitles != null && movie.subtitles!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    const Text('Subtitles', style: TextStyle(fontSize: AppTheme.subtitle, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: AppTheme.md),
                    Wrap(
                      spacing: AppTheme.sm,
                      runSpacing: AppTheme.sm,
                      children: movie.subtitles!.map((sub) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.rRound)),
                        child: Text(sub.languageName, style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropPlaceholder(Movie movie) {
    return Container(color: AppTheme.surface, child: Center(child: Text(movie.title.substring(0, 1.clamp(0, movie.title.length)), style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: AppTheme.textMuted))));
  }

  Widget _buildIconAction(IconData icon, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.2) : AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: active ? AppTheme.primary : AppTheme.divider),
        ),
        child: Icon(icon, size: 18, color: active ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}
