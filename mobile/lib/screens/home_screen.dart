import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_card.dart';

/// Home screen — Netflix-style layout with hero banner + category carousels
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> trending = [];
  List<Movie> popular = [];
  List<Movie> topRated = [];
  List<Movie> scifi = [];
  List<Movie> action = [];
  List<Movie> drama = [];
  List<Movie> horror = [];
  List<Movie> animation = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        MovieService.getTrending(limit: 10),
        MovieService.getPopular(limit: 10),
        MovieService.getTopRated(limit: 10),
        MovieService.getByCategory('scifi', limit: 10),
        MovieService.getByCategory('action', limit: 10),
        MovieService.getByCategory('drama', limit: 10),
        MovieService.getByCategory('horror', limit: 10),
        MovieService.getByCategory('animation', limit: 10),
      ]);
      if (mounted) {
        setState(() {
          trending = results[0];
          popular = results[1];
          topRated = results[2];
          scifi = results[3];
          action = results[4];
          drama = results[5];
          horror = results[6];
          animation = results[7];
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('HomeScreen load error: $e');
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Failed to load movies. Check your connection and try again.';
        });
      }
    }
  }

  void _openDetail(String movieId) {
    Navigator.pushNamed(context, '/movie_detail', arguments: movieId);
  }

  void _playMovie(Movie movie) {
    Navigator.pushNamed(context, '/player', arguments: {
      'movieId': movie.id,
      'title': movie.title,
    });
  }

  @override
  Widget build(BuildContext context) {
    final hero = trending.isNotEmpty ? trending.first : null;
    final sw = MediaQuery.of(context).size.width;

    // Error state
    if (error != null && !loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero billboard
          if (hero != null)
            SliverToBoxAdapter(child: _buildHero(hero, sw)),

          // Category carousels
          if (loading) ...[
            _buildSkeletonRow('Trending Now'),
            _buildSkeletonRow('Popular'),
          ] else ...[
            if (topRated.isNotEmpty) _buildCategoryRow('Top Rated', topRated),
            if (popular.isNotEmpty) _buildCategoryRow('Popular', popular),
            if (scifi.isNotEmpty) _buildCategoryRow('Sci-Fi & Fantasy', scifi),
            if (action.isNotEmpty) _buildCategoryRow('Action & Adventure', action),
            if (drama.isNotEmpty) _buildCategoryRow('Drama', drama),
            if (horror.isNotEmpty) _buildCategoryRow('Horror', horror),
            if (animation.isNotEmpty) _buildCategoryRow('Animation', animation),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHero(Movie movie, double sw) {
    return SizedBox(
      height: sw * 0.85,
      width: sw,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop image
          movie.backdropUrl.trim().isNotEmpty && movie.backdropUrl.trim() != ' '
              ? Image.network(
                  movie.backdropUrl.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildHeroPlaceholder(movie),
                )
              : _buildHeroPlaceholder(movie),

          // Gradient overlays
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xCC0D0D0D),
                  Color(0xFF0D0D0D),
                ],
                stops: [0.0, 0.5, 0.85, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            left: AppTheme.base,
            right: AppTheme.base,
            bottom: AppTheme.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TRENDING NOW',
                  style: TextStyle(
                    fontSize: AppTheme.caption,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTheme.heading,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Row(
                  children: [
                    if (movie.rating > 0) ...[
                      const Icon(Icons.star, size: 14, color: AppTheme.accentAmber),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: AppTheme.small, fontWeight: FontWeight.w600, color: AppTheme.accentAmber),
                      ),
                      const SizedBox(width: AppTheme.sm),
                    ],
                    Text(
                      '${movie.releaseYear}',
                      style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Text(
                      movie.durationFormatted,
                      style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.base),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _playMovie(movie),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        label: const Text('Play', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openDetail(movie.id),
                        icon: const Icon(Icons.info_outline, color: AppTheme.textPrimary, size: 20),
                        label: const Text('More Info', style: TextStyle(color: AppTheme.textPrimary)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceElevated,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPlaceholder(Movie movie) {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          movie.title.substring(0, 1.clamp(0, movie.title.length)),
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w900,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String title, List<Movie> movies) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.sectionGap),
          SectionHeader(title: title),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
              itemBuilder: (ctx, i) => MovieCard(
                movie: movies[i],
                onTap: () => _openDetail(movies[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow(String title) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.sectionGap),
          SectionHeader(title: title),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
              itemBuilder: (_, __) => const SkeletonCard(),
            ),
          ),
        ],
      ),
    );
  }
}
