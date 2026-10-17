import 'package:flutter_test/flutter_test.dart';

import 'package:peerplay/models/movie.dart';

VideoSource _source({String? magnet, String? stream}) {
  return VideoSource(
    id: 'src',
    movieId: 'movie',
    quality: '720p',
    magnetLink: magnet,
    streamUrl: stream,
    fileSizeBytes: 0,
    codec: 'h264',
  );
}

void main() {
  group('VideoSource.fromJson', () {
    test('parses a direct HTTP source', () {
      final source = VideoSource.fromJson({
        'id': 's1',
        'movie_id': 'm1',
        'quality': '720p',
        'magnet_link': '',
        'stream_url': 'https://archive.org/download/x/y.mp4',
        'file_size_bytes': 1234,
        'codec': 'h264',
      });

      expect(source.streamUrl, 'https://archive.org/download/x/y.mp4');
      expect(source.magnetLink, '');
      expect(source.fileSizeBytes, 1234);
      expect(source.isPlayable, isTrue);
      expect(source.fileSizeMB, '0 MB');
    });

    test('parses a magnet-only source', () {
      final source = VideoSource.fromJson({
        'quality': '1080p',
        'magnet_link': 'magnet:?xt=urn:btih:abc',
      });

      expect(source.streamUrl, isNull);
      expect(source.isPlayable, isTrue);
    });

    test('treats blank or missing fields as unplayable', () {
      expect(VideoSource.fromJson({}).isPlayable, isFalse);
      expect(_source(magnet: '  ', stream: '').isPlayable, isFalse);
    });
  });

  test('isPlayable accepts either transport', () {
    expect(_source(magnet: 'magnet:?xt=urn:btih:abc').isPlayable, isTrue);
    expect(_source(stream: 'https://example.com/a.mp4').isPlayable, isTrue);
    expect(_source(magnet: null, stream: null).isPlayable, isFalse);
  });
}
