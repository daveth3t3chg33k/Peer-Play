import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/auth_service.dart';
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
  List<VideoSource> _sources = [];
  List<CastMember> _cast = [];
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    try {
      final results = await Future.wait([
        MovieService.getMovie(widget.movieId),
        MovieService.getStreamSources(widget.movieId).catchError((_) => <VideoSource>[]),
        MovieService.getMovieCredits(widget.movieId).catchError((_) => <CastMember>[]),
      ]);
      if (mounted) {
        setState(() {
          _movie = results[0] as Movie;
          _sources = results[1] as List<VideoSource>;
          _cast = results[2] as List<CastMember>;
          _loading = false;
        });
      }
      _checkBookmark();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkBookmark() async {
    if (_movie == null) return;
    final isAuth = await AuthService.isAuthenticated();
    if (!isAuth) return;
    final ids = await MovieService.getBookmarkedIds();
    if (mounted) setState(() => _isBookmarked = ids.contains(_movie!.id));
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
      success = await MovieService.removeBookmark(_movie!.id);
    } else {
      success = await MovieService.addBookmark(_movie!.id);
    }
    if (!success && mounted) setState(() => _isBookmarked = wasBookmarked);
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

  void _playTrailer() {
    if (_movie?.trailerKey == null) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=${_movie!.trailerKey}');
    launchUrl(url, mode: LaunchMode.externalApplication);
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
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
                  // Trailer play button overlay
                  if (movie.trailerKey != null)
                    Center(
                      child: GestureDetector(
                        onTap: _playTrailer,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
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
                          onPressed: () {
                            String? magnetLink;
                            if (_sources.isNotEmpty) {
                              magnetLink = _sources.first.magnetLink;
                            }
                            Navigator.pushNamed(context, '/player', arguments: {
                              'movieId': movie.id,
                              'title': movie.title,
                              'magnetLink': magnetLink,
                            });
                          },
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      _buildIconAction(
                        _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                        _isBookmarked,
                        _toggleBookmark,
                      ),
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

                  // Cast & Crew
                  if (_cast.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    Text(
                      'CAST',
                      style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1),
                    ),
                    const SizedBox(height: AppTheme.md),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.md),
                        itemBuilder: (context, index) {
                          final member = _cast[index];
                          return SizedBox(
                            width: 80,
                            child: Column(
                              children: [
                                // Profile photo
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: member.profileUrl.isNotEmpty
                                      ? Image.network(
                                          member.profileUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(member.name),
                                        )
                                      : _buildAvatarPlaceholder(member.name),
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  member.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: AppTheme.small, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  member.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Sources
                  if (_sources.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    Text(
                      'AVAILABLE SOURCES',
                      style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1),
                    ),
                    const SizedBox(height: AppTheme.md),
                    ..._sources.map((s) => GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/player', arguments: {
                        'movieId': movie.id,
                        'title': movie.title,
                        'magnetLink': s.magnetLink,
                      }),
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

  Widget _buildAvatarPlaceholder(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: active ? AppTheme.primary : AppTheme.divider),
        ),
        child: Icon(icon, size: 18, color: active ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}
