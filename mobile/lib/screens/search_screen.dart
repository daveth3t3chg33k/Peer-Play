import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';

/// Search screen — Netflix-style search with grid results
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Movie> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() { _loading = true; _hasSearched = true; });
    try {
      final response = await MovieService.searchMovies(q: query);
      if (mounted) setState(() { _results = response.data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final colW = (sw - AppTheme.base * 2 - AppTheme.sm) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.base, AppTheme.xxl, AppTheme.base, AppTheme.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search', style: TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: AppTheme.base),
              TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Movies, genres...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
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
              ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2))
              : !_hasSearched
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_rounded, size: 44, color: AppTheme.textMuted), SizedBox(height: AppTheme.sm), Text('Search for movies', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))]))
                  : _results.isEmpty
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off_rounded, size: 44, color: AppTheme.textMuted), SizedBox(height: AppTheme.sm), Text('No results found', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))]))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: colW / (colW * 1.4 + 36), crossAxisSpacing: AppTheme.sm, mainAxisSpacing: AppTheme.base),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) => MovieCard(movie: _results[i], width: colW, height: colW * 1.4, onTap: () => Navigator.pushNamed(context, '/movie_detail', arguments: _results[i].id)),
                        ),
        ),
      ],
    );
  }
}
