import 'dart:io';

import 'package:anytime/entities/episode.dart';
import 'package:anytime/services/youtube/youtube_service.dart';
import 'package:anytime/services/youtube/youtube_types.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves YouTube placeholder URLs to real audio stream URLs.
///
/// This is a thin service that sits between the audio player / downloader
/// and [YouTubeService]. For episodes with `contentUrl` in the format
/// `youtube://{videoId}`, it resolves to an actual HTTPS audio URL.
/// Regular episodes (audio podcasts) pass through unchanged.
///
/// For streaming, downloads the audio to a temporary file using an HTTP
/// client with YouTube-appropriate headers to avoid 403 errors from
/// Google's CDN.
class YouTubeAudioResolver {
  final _log = Logger('YouTubeAudioResolver');

  final YouTubeService _youtubeService;
  final http.Client _httpClient;

  /// Default quality to use when none is specified.
  YouTubeQuality defaultQuality;

  /// URL scheme for YouTube placeholder URLs.
  static const youtubeScheme = 'youtube://';

  /// User-Agent matching what youtube_explode_dart uses.
  static const _userAgent = 'Mozilla/5.0 (compatible; AnytimePodcastPlayer/1.0)';

  YouTubeAudioResolver({
    required YouTubeService youtubeService,
    this.defaultQuality = YouTubeQuality.low,
    http.Client? httpClient,
  })  : _youtubeService = youtubeService,
        _httpClient = httpClient ?? http.Client();

  /// Resolves an episode's [contentUrl] to a playable file:// URI.
  ///
  /// Downloads the YouTube audio to a temporary file using headers
  /// that satisfy Google CDN's authentication requirements, then
  /// returns a file:// URI that just_audio can play without issues.
  Future<String> resolveAudioUrl(
    Episode episode, {
    YouTubeQuality? quality,
  }) async {
    final contentUrl = episode.contentUrl;
    if (contentUrl == null || !contentUrl.startsWith(youtubeScheme)) {
      return contentUrl ?? '';
    }

    final videoId = extractVideoId(contentUrl);
    if (videoId == null) {
      _log.warning('Invalid YouTube content URL: $contentUrl');
      throw YouTubeResolveException('Invalid YouTube content URL: $contentUrl');
    }

    _log.fine('Resolving audio URL for video $videoId');
    try {
      final audioUrl = await _youtubeService.extractAudioUrl(
        videoId,
        quality: quality ?? defaultQuality,
      );
      _log.fine('Got CDN URL for $videoId: ${audioUrl.length} chars');

      // Download audio to temp file with YouTube headers.
      final tempDir = await getTemporaryDirectory();
      final fileName = 'yt_audio_$videoId.m4a';
      final file = File('${tempDir.path}/$fileName');

      // Only download if not already cached.
      if (!await file.exists()) {
        _log.fine('Downloading YouTube audio to temp file: $fileName');
        final response = await _httpClient.get(
          Uri.parse(audioUrl),
          headers: {
            'User-Agent': _userAgent,
            'Referer': 'https://www.youtube.com/',
            'Accept': '*/*',
          },
        );
        if (response.statusCode != 200) {
          throw YouTubeResolveException('Download failed: HTTP ${response.statusCode}');
        }
        await file.writeAsBytes(response.bodyBytes);
        _log.fine('Downloaded ${response.bodyBytes.length} bytes to $fileName');
      } else {
        _log.fine('Using cached temp file: $fileName');
      }

      return 'file://${file.path}';
    } catch (e, stack) {
      _log.warning('Failed to resolve audio for $videoId: $e', e, stack);
      rethrow;
    }
  }

  /// Extracts the YouTube video ID from a `youtube://{videoId}` URL.
  static String? extractVideoId(String contentUrl) {
    if (!contentUrl.startsWith(youtubeScheme)) return null;
    final videoId = contentUrl.substring(youtubeScheme.length);
    if (videoId.isEmpty) return null;
    return videoId;
  }

  /// Returns true if the episode's content URL is a YouTube placeholder.
  static bool isYouTubeEpisode(Episode? episode) {
    if (episode == null) return false;
    final url = episode.contentUrl;
    return url != null && url.startsWith(youtubeScheme);
  }
}

/// Exception thrown when YouTube audio URL resolution fails.
class YouTubeResolveException implements Exception {
  final String message;

  YouTubeResolveException(this.message);

  @override
  String toString() => 'YouTubeResolveException: $message';
}
