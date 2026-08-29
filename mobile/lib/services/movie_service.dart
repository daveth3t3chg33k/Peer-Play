import 'dart:convert';
import '../config/api.dart';
import '../models/movie.dart';

class MovieService {
  static Future<PaginatedResponse<Movie>> getMovies({int page = 1, int pageSize = 20}) async {
    final response = await ApiClient.get('/movies', queryParams: {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
    return PaginatedResponse.fromJson(jsonDecode(response.body), Movie.fromJson);
  }

  static Future<Movie> getMovie(String id) async {
    final response = await ApiClient.get('/movies/$id');
    return Movie.fromJson(jsonDecode(response.body));
  }

  static Future<List<Movie>> getTrending({int limit = 10}) async {
    final response = await ApiClient.get('/movies/trending', queryParams: {'limit': limit.toString()});
    final List data = jsonDecode(response.body);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<List<Movie>> getRecent({int limit = 10}) async {
    final response = await ApiClient.get('/movies/recent', queryParams: {'limit': limit.toString()});
    final List data = jsonDecode(response.body);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<List<Movie>> getPopular({int limit = 20}) async {
    final response = await ApiClient.get('/movies/popular', queryParams: {'limit': limit.toString()});
    final List data = jsonDecode(response.body);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<List<Movie>> getTopRated({int limit = 20}) async {
    final response = await ApiClient.get('/movies/top-rated', queryParams: {'limit': limit.toString()});
    final List data = jsonDecode(response.body);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<List<Movie>> getByCategory(String category, {int limit = 20}) async {
    final response = await ApiClient.get('/movies/by-category/$category', queryParams: {'limit': limit.toString()});
    final List data = jsonDecode(response.body);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<List<String>> getGenres() async {
    final response = await ApiClient.get('/movies/genres');
    final List data = jsonDecode(response.body);
    return data.cast<String>();
  }

  static Future<PaginatedResponse<Movie>> searchMovies({
    String? q,
    List<String>? genres,
    int? yearFrom,
    int? yearTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (genres != null && genres.isNotEmpty) params['genres'] = genres.join(',');
    if (yearFrom != null) params['year_from'] = yearFrom.toString();
    if (yearTo != null) params['year_to'] = yearTo.toString();
    final response = await ApiClient.get('/movies/search', queryParams: params);
    return PaginatedResponse.fromJson(jsonDecode(response.body), Movie.fromJson);
  }
}
