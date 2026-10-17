import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/auth_service.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_card.dart';

/// Home screen — Netflix-style layout with hero banner, genre filter bar, and category carousels.
/// Genre filter bar lets users jump to a category by tapping, with active indicator.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  // Category data stored in a map for easy iteration
  final Map<String, List<Movie>> _categories = {};

  // Ordered lists of display names and their keys
  static const _categoryOrder = [
    'Top Rated', 'Popular', 'Sci-Fi & Fantasy', 'Action & Adventure',
    'Drama', 'Horror', 'Animation', 'Comedy', 'Thriller', 'Romance',
    'Crime', 'Fantasy', 'War', 'Family',
  ];
  static const _categoryKeys = [
    'top_rated', 'popular', 'scifi', 'action',
    'drama', 'horror', 'animation', 'comedy', 'thriller', 'romance',
    'crime', 'fantasy', 'war', 'family',
  ];

  // Keys to measure each category row's position in the scroll view
  final Map<String, GlobalKey> _rowKeys = {
    for (var key in _categoryKeys) key: GlobalKey(),
  };

  // Active genre tracking
  int _activeCategoryIndex = 0;

  List<WatchHistoryEntry> continueWatching = [];
  List<Movie> bookmarkedMovies = [];
  Set<String> bookmarkedIds = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_scrollController.hasListeners) return;
    _updateActiveCategory();
  }

  void _updateActiveCategory() {
    if (!_scrollController.hasClients) return;
    final viewportTop = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Find which category row is closest to the top of the viewport
    int closestIndex = 0;
    double closestDistance = double.infinity;

    for (var i = 0; i < _categoryKeys.length; i++) {
      final key = _rowKeys[_categoryKeys[i]];
      if (key == null || key.currentContext == null) continue;

      final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final position = renderBox.localToGlobal(Offset.zero, ancestor: null);
      final distance = (position.dy - viewportTop).abs();

      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != _activeCategoryIndex && mounted) {
      setState(() => _activeCategoryIndex = closestIndex);
    }
  }

  void _scrollToCategory(int index) {
    final key = _rowKeys[_categoryKeys[index]];
    if (key == null || key.currentContext == null) return;

    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Scroll so the category row is near the top with a small offset for the filter bar
    final position = renderBox.localToGlobal(Offset.zero, ancestor: null);
    final offset = _scrollController.offset + position.dy - 100; // 100px offset for filter bar

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
      _categories.clear();
      continueWatching = [];
    });

    try {
      // Load trending first for hero banner
      final t = await MovieService.getTrending(limit: 10);
      if (!mounted) return;
      setState(() => _categories['trending'] = t);

      // Load user-specific data (only if authenticated)
      _loadContinueWatching();
      _loadBookmarks();

      // Load categories sequentially to avoid DB pool saturation
      for (var i = 0; i < _categoryKeys.length; i++) {
        final key = _categoryKeys[i];
        final movies = await MovieService.getByCategory(key, limit: 10);
        if (!mounted) return;
        if (movies.isNotEmpty) {
          setState(() => _categories[key] = movies);
        }
      }

      // Done loading categories
      if (mounted) setState(() => loading = false);
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

  Future<void> _loadContinueWatching() async {
    try {
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth || !mounted) return;
      final history = await MovieService.getWatchHistory(pageSize: 10);
      if (!mounted) return;
      final incomplete = history.where((h) => !h.completed && h.movie != null).toList();
      if (incomplete.isEmpty) return;
      final movieIds = incomplete.map((h) => h.movieId).toList();
      final movies = await MovieService.getMoviesByIDs(movieIds);
      if (!mounted) return;
      final movieMap = {for (var m in movies) m.id: m};
      final enriched = incomplete
          .where((h) => movieMap.containsKey(h.movieId))
          .map((h) => WatchHistoryEntry(
                id: h.id, movieId: h.movieId,
                progressSeconds: h.progressSeconds, completed: h.completed,
                lastWatchedAt: h.lastWatchedAt, movie: movieMap[h.movieId],
              ))
          .toList();
      if (mounted) setState(() => continueWatching = enriched);
    } catch (e) {
      debugPrint('ContinueWatching load error: $e');
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth || !mounted) return;
      final ids = await MovieService.getBookmarkedIds();
      if (!mounted || ids.isEmpty) return;
      final movies = await MovieService.getMoviesByIDs(ids.toList());
      if (!mounted) return;
      setState(() { bookmarkedIds = ids; bookmarkedMovies = movies; });
    } catch (e) {
      debugPrint('Bookmarks load error: $e');
    }
  }

  void _openDetail(String movieId) {
    Navigator.pushNamed(context, '/movie_detail', arguments: movieId);
  }

  void _playMovie(Movie movie) {
    Navigator.pushNamed(context, '/player', arguments: {
      'movieId': movie.id, 'title': movie.title,
    });
  }

  @override
  Widget build(BuildContext context) {
    final trendingMovies = _categories['trending'] ?? [];
    final hero = trendingMovies.isNotEmpty ? trendingMovies.first : null;
    final sw = MediaQuery.of(context).size.width;

    if (error != null && !loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
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
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero billboard
          if (hero != null) SliverToBoxAdapter(child: _buildHero(hero, sw)),

          // Genre filter bar (only when categories are loaded)
          if (!loading && _categories.isNotEmpty) _buildGenreFilterBar(),

          // Continue Watching row
          if (continueWatching.isNotEmpty) _buildContinueWatchingRow(),

          // My List row
          if (bookmarkedMovies.isNotEmpty) _buildMyListRow(),

          // Category carousels
          if (loading && trendingMovies.isEmpty) ...[
            _buildSkeletonRow('Loading'),
          ] else ...[
            for (var i = 0; i < _categoryOrder.length; i++)
              if (_categories[_categoryKeys[i]]?.isNotEmpty == true)
                _buildCategoryRow(_categoryOrder[i], _categoryKeys[i], _categories[_categoryKeys[i]]!),
            if (loading) _buildSkeletonRow('Loading more...'),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildGenreFilterBar() {
    return SliverToBoxAdapter(
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
          itemCount: _categoryOrder.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (ctx, i) {
            final isActive = i == _activeCategoryIndex;
            return GestureDetector(
              onTap: () => _scrollToCategory(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppTheme.primary : AppTheme.divider,
                    width: 1,
                  ),
                ),
                child: Text(
                  _categoryOrder[i],
                  style: TextStyle(
                    fontSize: AppTheme.small,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
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
          movie.backdropUrl.trim().isNotEmpty && movie.backdropUrl.trim() != ' '
              ? Image.network(movie.backdropUrl.trim(), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildHeroPlaceholder(movie))
              : _buildHeroPlaceholder(movie),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Color(0xCC0D0D0D), Color(0xFF0D0D0D)],
                stops: [0.0, 0.5, 0.85, 1.0],
              ),
            ),
          ),
          Positioned(
            left: AppTheme.base, right: AppTheme.base, bottom: AppTheme.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TRENDING NOW', style: TextStyle(fontSize: AppTheme.caption,
                    fontWeight: FontWeight.w600, color: AppTheme.primary, letterSpacing: 1.5)),
                const SizedBox(height: AppTheme.sm),
                Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary, letterSpacing: -0.5, height: 1.1)),
                const SizedBox(height: AppTheme.sm),
                Row(children: [
                  if (movie.rating > 0) ...[
                    const Icon(Icons.star, size: 14, color: AppTheme.accentAmber),
                    const SizedBox(width: 4),
                    Text(movie.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: AppTheme.small, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                    const SizedBox(width: AppTheme.sm),
                  ],
                  Text('${movie.releaseYear}', style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary)),
                  const SizedBox(width: AppTheme.sm),
                  Text(movie.durationFormatted, style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: AppTheme.base),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _playMovie(movie),
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    label: const Text('Play', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  )),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _openDetail(movie.id),
                    icon: const Icon(Icons.info_outline, color: AppTheme.textPrimary, size: 20),
                    label: const Text('More Info', style: TextStyle(color: AppTheme.textPrimary)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceElevated,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  )),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPlaceholder(Movie movie) {
    return Container(color: AppTheme.surface, child: Center(
      child: Text(movie.title.substring(0, 1.clamp(0, movie.title.length)),
        style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: AppTheme.textMuted)),
    ));
  }

  Widget _buildMyListRow() {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppTheme.sectionGap),
        SectionHeader(title: 'My List'),
        SizedBox(height: 220, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
          itemCount: bookmarkedMovies.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
          itemBuilder: (ctx, i) => MovieCard(movie: bookmarkedMovies[i],
            onTap: () => _openDetail(bookmarkedMovies[i].id),
            bookmarkedIds: bookmarkedIds, onBookmarkChanged: () => _loadBookmarks()),
        )),
      ]),
    );
  }

  Widget _buildContinueWatchingRow() {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppTheme.sectionGap),
        SectionHeader(title: 'Continue Watching'),
        SizedBox(height: 200, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
          itemCount: continueWatching.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
          itemBuilder: (ctx, i) {
            final entry = continueWatching[i];
            final movie = entry.movie!;
            return _ContinueWatchingCard(movie: movie, progress: entry.progressFraction,
              progressLabel: entry.progressLabel,
              onTap: () => _openDetail(movie.id), onPlay: () => _playMovie(movie));
          },
        )),
      ]),
    );
  }

  Widget _buildCategoryRow(String title, String categoryKey, List<Movie> movies) {
    return SliverToBoxAdapter(
      key: _rowKeys[categoryKey],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppTheme.sectionGap),
        SectionHeader(title: title),
        SizedBox(height: 220, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
          itemCount: movies.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
          itemBuilder: (ctx, i) => MovieCard(movie: movies[i],
            onTap: () => _openDetail(movies[i].id)),
        )),
      ]),
    );
  }

  Widget _buildSkeletonRow(String title) {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppTheme.sectionGap),
        SectionHeader(title: title),
        SizedBox(height: 220, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
          itemBuilder: (_, __) => const SkeletonCard(),
        )),
      ]),
    );
  }
}

/// Card for the Continue Watching row — shows poster with progress bar overlay.
class _ContinueWatchingCard extends StatelessWidget {
  final Movie movie;
  final double progress;
  final String progressLabel;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _ContinueWatchingCard({
    required this.movie, required this.progress,
    required this.progressLabel, required this.onTap, required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 130, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: movie.posterUrl.trim().isNotEmpty
                  ? Image.network(movie.posterUrl.trim(), fit: BoxFit.cover,
                      width: 130, height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildPlaceholder())
                  : _buildPlaceholder()),
            Positioned.fill(child: Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6)),
              child: Center(child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              )),
            )),
          ])),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: progress, minHeight: 3,
              backgroundColor: AppTheme.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary))),
          const SizedBox(height: 4),
          Text(progressLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      )),
    );
  }

  Widget _buildPlaceholder() {
    return Container(width: 130, color: AppTheme.surface, child: Center(
      child: Text(movie.title.substring(0, 1.clamp(0, movie.title.length)),
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.textMuted)),
    ));
  }
}
