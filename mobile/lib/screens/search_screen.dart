import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';

/// Search screen — genre filter chips, recent search suggestions, debounced text search.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Movie> _results = [];
  List<String> _genres = [];
  List<String> _recentSearches = [];
  Set<String> _selectedGenres = {};
  bool _loading = false;
  bool _hasSearched = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _loadRecentSearches();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _showSuggestions = _focusNode.hasFocus && !_hasSearched);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await MovieService.getGenres();
      if (mounted) setState(() => _genres = genres);
    } catch (_) {}
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) setState(() => _recentSearches = searches);
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = List<String>.from(_recentSearches);
    searches.remove(query); // Remove if already exists (move to top)
    searches.insert(0, query);
    if (searches.length > _maxRecentSearches) {
      searches.removeLast();
    }
    await prefs.setStringList(_recentSearchesKey, searches);
    if (mounted) setState(() => _recentSearches = searches);
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = List<String>.from(_recentSearches);
    searches.remove(query);
    await prefs.setStringList(_recentSearchesKey, searches);
    if (mounted) setState(() => _recentSearches = searches);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() { _results = []; _hasSearched = false; _showSuggestions = _focusNode.hasFocus; });
      return;
    }
    setState(() => _showSuggestions = false);
    _debounce = Timer(const Duration(milliseconds: 400), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty && _selectedGenres.isEmpty) return;
    setState(() { _loading = true; _hasSearched = true; _showSuggestions = false; });
    if (query.trim().isNotEmpty) _saveRecentSearch(query.trim());
    try {
      final response = await MovieService.searchMovies(
        q: query.trim().isNotEmpty ? query.trim() : null,
        genres: _selectedGenres.isNotEmpty ? _selectedGenres.toList() : null,
      );
      if (mounted) setState(() { _results = response.data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  void _toggleGenre(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
    });
    // Re-run search if we've already searched or have selected genres
    if (_hasSearched || _selectedGenres.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _selectSuggestion(String query) {
    _searchController.text = query;
    _focusNode.unfocus();
    _performSearch(query);
  }

  void _clearAll() {
    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _results = [];
      _hasSearched = false;
      _selectedGenres = {};
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final colW = (sw - AppTheme.base * 2 - AppTheme.sm) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.base, AppTheme.xxl, AppTheme.base, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search', style: TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: AppTheme.base),
              TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Movies, genres...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty || _selectedGenres.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                          onPressed: _clearAll,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // Genre filter chips
        if (_genres.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.base, vertical: AppTheme.sm),
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final genre = _genres[i];
                final selected = _selectedGenres.contains(genre);
                return GestureDetector(
                  onTap: () => _toggleGenre(genre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.rRound),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        fontSize: AppTheme.small,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Active genre filter bar
        if (_selectedGenres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
            child: Row(
              children: [
                Icon(Icons.filter_alt_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${_selectedGenres.length} genre${_selectedGenres.length > 1 ? 's' : ''} selected',
                  style: TextStyle(fontSize: AppTheme.small, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () { setState(() => _selectedGenres = {}); _performSearch(_searchController.text); },
                  child: Text('Clear', style: TextStyle(fontSize: AppTheme.small, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppTheme.sm),

        // Content area
        Expanded(
          child: _showSuggestions
              ? _buildSuggestionsList()
              : _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2))
                  : !_hasSearched && _selectedGenres.isEmpty
                      ? _buildEmptyState()
                      : _results.isEmpty
                          ? _buildNoResults()
                          : _buildResultsGrid(colW),
        ),
      ],
    );
  }

  Widget _buildSuggestionsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
      children: [
        // Recent searches
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sm),
            child: Row(
              children: [
                Text(
                  'RECENT SEARCHES',
                  style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_recentSearchesKey);
                    setState(() => _recentSearches = []);
                  },
                  child: Text('Clear all', style: TextStyle(fontSize: AppTheme.small, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),
          ..._recentSearches.map((term) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, size: 18, color: AppTheme.textMuted),
            title: Text(term, style: const TextStyle(color: AppTheme.textPrimary, fontSize: AppTheme.body)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
              onPressed: () => _removeRecentSearch(term),
            ),
            onTap: () => _selectSuggestion(term),
          )),
          const SizedBox(height: AppTheme.md),
        ],

        // Quick genre suggestions
        Text(
          'BROWSE BY GENRE',
          style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1),
        ),
        const SizedBox(height: AppTheme.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _genres.map((genre) => GestureDetector(
            onTap: () {
              _toggleGenre(genre);
              _focusNode.unfocus();
              _performSearch('');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.rRound),
              ),
              child: Text(genre, style: const TextStyle(fontSize: AppTheme.small, color: AppTheme.textSecondary)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 44, color: AppTheme.textMuted),
          const SizedBox(height: AppTheme.sm),
          const Text('Search for movies', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body)),
          const SizedBox(height: AppTheme.xs),
          Text('or tap a genre to browse', style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.small)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppTheme.textMuted),
          const SizedBox(height: AppTheme.sm),
          const Text('No results found', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body)),
          const SizedBox(height: AppTheme.xs),
          Text('Try different keywords or genres', style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.small)),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(double colW) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: colW / (colW * 1.4 + 36),
        crossAxisSpacing: AppTheme.sm,
        mainAxisSpacing: AppTheme.base,
      ),
      itemCount: _results.length,
      itemBuilder: (ctx, i) => MovieCard(
        movie: _results[i],
        width: colW,
        height: colW * 1.4,
        onTap: () => Navigator.pushNamed(context, '/movie_detail', arguments: _results[i].id),
      ),
    );
  }
}
