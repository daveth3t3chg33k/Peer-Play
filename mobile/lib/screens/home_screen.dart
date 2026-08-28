import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> trending = [];
  List<Movie> recent = [];
  bool loadingTrending = true;
  bool loadingRecent = true;
  String activeGenre = 'All';
  bool refreshing = false;

  static const genres = ['All', 'Action', 'Sci-Fi', 'Drama', 'Comedy', 'Thriller', 'Horror', 'Animation'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { loadingTrending = true; loadingRecent = true; });
    try {
      final t = await MovieService.getTrending(limit: 10);
      final r = await MovieService.getRecent(limit: 10);
      setState(() {
        trending = t;
        recent = r;
        loadingTrending = false;
        loadingRecent = false;
      });
    } catch (e) {
      setState(() { loadingTrending = false; loadingRecent = false; });
    }
  }

  Future<void> _onRefresh() async {
    setState(() { refreshing = true; });
    await _loadData();
    setState(() { refreshing = false; });
  }

  void _navigateToDetail(String movieId) {
    Navigator.pushNamed(context, '/movie_detail', arguments: movieId);
  }

  void _navigateToPlayer(String movieId, String title) {
    Navigator.pushNamed(context, '/player', arguments: {'movieId': movieId, 'title': title});
  }

  @override
  Widget build(BuildContext context) {
    final hero = trending.isNotEmpty ? trending.first : null;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // ── Hero Billboard ──
          if (hero != null)
            SliverToBoxAdapter(
              child: SizedBox(
                width: sw,
                height: sh * 0.58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background
                    Container(
                      color: AppTheme.surfaceLight,
                      child: Center(
                        child: Text(
                          hero.initial,
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryLight.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    // Bottom gradient + content
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingBase),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppTheme.background],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRENDING NOW',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeSmall,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXs),
                              Text(
                                hero.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeHeading,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXs),
                              Text(
                                '${hero.releaseYear} · ${hero.durationFormatted} · ⭐ ${hero.rating.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeSmall,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingBase),
                              Row(
                                children: [
                                  // Play button
                                  ElevatedButton.icon(
                                    onPressed: () => _navigateToPlayer(hero.id, hero.title),
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                    label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingSm),
                                  // Info button
                                  OutlinedButton.icon(
                                    onPressed: () => _navigateToDetail(hero.id),
                                    icon: const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                                    label: const Text('More Info', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppTheme.surfaceLight,
                                      side: const BorderSide(color: AppTheme.border),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Genre Chips ──
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                itemCount: genres.length,
                itemBuilder: (ctx, i) => GenreChip(
                  label: genres[i],
                  selected: activeGenre == genres[i],
                  onTap: () => setState(() => activeGenre = genres[i]),
                ),
              ),
            ),
          ),

          // ── Trending Row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSection, bottom: AppTheme.spacingMd),
              child: SectionHeader(
                title: 'Trending Now',
                icon: Icons.trending_up_rounded,
                iconColor: AppTheme.accent,
                onSeeAll: () {},
              ),
            ),
          ),
          if (loadingTrending)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSm),
                  itemBuilder: (_, __) => const SkeletonCard(),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                  itemCount: trending.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSm),
                  itemBuilder: (ctx, i) => MovieCard(
                    title: trending[i].title,
                    initial: trending[i].initial,
                    rating: trending[i].rating,
                    releaseYear: trending[i].releaseYear,
                    onTap: () => _navigateToDetail(trending[i].id),
                  ),
                ),
              ),
            ),

          // ── Recently Added Row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSection, bottom: AppTheme.spacingMd),
              child: SectionHeader(
                title: 'Recently Added',
                icon: Icons.access_time_rounded,
                iconColor: AppTheme.accentBlue,
                onSeeAll: () {},
              ),
            ),
          ),
          if (loadingRecent)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSm),
                  itemBuilder: (_, __) => const SkeletonCard(),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spacingSm),
                  itemBuilder: (ctx, i) => MovieCard(
                    title: recent[i].title,
                    initial: recent[i].initial,
                    rating: recent[i].rating,
                    releaseYear: recent[i].releaseYear,
                    onTap: () => _navigateToDetail(recent[i].id),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
