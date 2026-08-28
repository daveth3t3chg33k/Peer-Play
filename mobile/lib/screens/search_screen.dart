import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Movie> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() { _loading = true; _hasSearched = true; });
    try {
      final response = await MovieService.searchMovies(q: query);
      setState(() { _results = response.data; _loading = false; });
    } catch (e) {
      setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final colW = (sw - AppTheme.spacingBase * 2 - AppTheme.spacingSm) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingBase, AppTheme.spacingXxl, AppTheme.spacingBase, AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search', style: TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5)),
              const SizedBox(height: AppTheme.spacingBase),
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: 'Movies, genres, actors...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textTertiary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
                          onPressed: () { _searchController.clear(); _onSearchChanged(''); },
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : !_hasSearched
                  ? _buildEmptyState(Icons.search_rounded, 'Find Your Next Watch', 'Search by title, genre, or actor')
                  : _results.isEmpty
                      ? _buildEmptyState(Icons.search_off_rounded, 'No results found', 'Try a different search term')
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: colW / (colW * 1.4 + 40),
                            crossAxisSpacing: AppTheme.spacingSm,
                            mainAxisSpacing: AppTheme.spacingBase,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) => _buildGridCard(_results[i], colW),
                        ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String desc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: AppTheme.spacingSm),
          Text(title, style: const TextStyle(fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: AppTheme.spacingXs),
          Text(desc, style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGridCard(Movie movie, double colW) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/movie_detail', arguments: movie.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: colW, height: colW * 1.4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                movie.initial,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.primaryLight.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text)),
          Row(
            children: [
              if (movie.rating > 0) ...[
                const Icon(Icons.star_rounded, size: 11, color: AppTheme.accentAmber),
                const SizedBox(width: 2),
                Text(movie.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
              ],
              if (movie.rating > 0 && movie.releaseYear > 0) const SizedBox(width: 4),
              Text(movie.releaseYear.toString(), style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
