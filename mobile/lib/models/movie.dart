/// Movie model — mirrors the Go backend's movie schema
class Movie {
  final String id;
  final String title;
  final String description;
  final int releaseYear;
  final List<String> genres;
  final String posterUrl;
  final String backdropUrl;
  final int durationMinutes;
  final double rating;
  final String? infoHash;
  final String category;
  final String createdAt;
  final String updatedAt;
  final List<VideoSource>? sources;
  final List<Subtitle>? subtitles;

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.releaseYear,
    required this.genres,
    required this.posterUrl,
    required this.backdropUrl,
    required this.durationMinutes,
    required this.rating,
    this.infoHash,
    this.category = '',
    required this.createdAt,
    required this.updatedAt,
    this.sources,
    this.subtitles,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      releaseYear: json['release_year'] ?? 0,
      genres: List<String>.from(json['genres'] ?? []),
      posterUrl: json['poster_url'] ?? '',
      backdropUrl: json['backdrop_url'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      infoHash: json['info_hash'],
      category: json['category'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      sources: json['sources'] != null
          ? (json['sources'] as List).map((s) => VideoSource.fromJson(s)).toList()
          : null,
      subtitles: json['subtitles'] != null
          ? (json['subtitles'] as List).map((s) => Subtitle.fromJson(s)).toList()
          : null,
    );
  }

  String get durationFormatted {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return '${h}h ${m}m';
  }
}

class VideoSource {
  final String id;
  final String movieId;
  final String quality;
  final String? magnetLink;
  final int fileSizeBytes;
  final String codec;

  VideoSource({
    required this.id,
    required this.movieId,
    required this.quality,
    this.magnetLink,
    required this.fileSizeBytes,
    required this.codec,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id']?.toString() ?? '',
      movieId: json['movie_id']?.toString() ?? '',
      quality: json['quality'] ?? '',
      magnetLink: json['magnet_link'],
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      codec: json['codec'] ?? '',
    );
  }

  String get fileSizeMB => '${(fileSizeBytes / 1048576).toStringAsFixed(0)} MB';
}

class Subtitle {
  final String id;
  final String movieId;
  final String languageCode;
  final String languageName;
  final String fileUrl;
  final String format;

  Subtitle({
    required this.id,
    required this.movieId,
    required this.languageCode,
    required this.languageName,
    required this.fileUrl,
    required this.format,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      id: json['id']?.toString() ?? '',
      movieId: json['movie_id']?.toString() ?? '',
      languageCode: json['language_code'] ?? '',
      languageName: json['language_name'] ?? '',
      fileUrl: json['file_url'] ?? '',
      format: json['format'] ?? '',
    );
  }
}

class CastMember {
  final String id;
  final String movieId;
  final String name;
  final String character;
  final String profilePath;
  final String department;
  final int order;

  CastMember({
    required this.id,
    required this.movieId,
    required this.name,
    required this.character,
    required this.profilePath,
    required this.department,
    required this.order,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id']?.toString() ?? '',
      movieId: json['movie_id']?.toString() ?? '',
      name: json['name'] ?? '',
      character: json['character'] ?? '',
      profilePath: json['profile_path'] ?? '',
      department: json['department'] ?? 'Acting',
      order: json['sort_order'] ?? json['order'] ?? 0,
    );
  }

  String get profileUrl {
    if (profilePath.isEmpty) return '';
    if (profilePath.startsWith('http')) return profilePath;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int total;

  PaginatedResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse(
      data: (json['data'] as List).map((e) => fromJsonT(e)).toList(),
      page: json['pagination']?['page'] ?? 1,
      pageSize: json['pagination']?['page_size'] ?? 20,
      total: json['pagination']?['total'] ?? 0,
    );
  }
}

class User {
  final String id;
  final String email;
  final String displayName;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AuthResponse {
  final String token;
  final int expiresAt;
  final User user;

  AuthResponse({required this.token, required this.expiresAt, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      expiresAt: json['expires_at'] ?? 0,
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
