// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:anytime/services/youtube/youtube_service.dart';
import 'package:anytime/services/youtube/youtube_types.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Implementation of [YouTubeService] using the Invidious API.
///
/// Invidious is an open-source YouTube frontend that provides a clean
/// JSON API. This implementation queries a configurable Invidious instance
/// to extract audio stream URLs without needing a YouTube API key.
///
/// Uses an in-memory cache with 30-minute TTL to avoid redundant API calls
/// for the same video during a session.
class MobileYouTubeService extends YouTubeService {
  final _log = Logger('MobileYouTubeService');

  /// The Invidious instance base URL.
  final String invidiousBaseUrl;

  /// Default quality when none is specified.
  final YouTubeQuality defaultQuality;

  /// HTTP client for API calls.
  final http.Client _httpClient;

  /// youtube_explode_dart client for direct YouTube extraction.
  yt.YoutubeExplode? _youtubeExplode;

  /// In-memory cache: videoId → cached URL with expiry.
  final Map<String, _CachedUrl> _urlCache = {};
  final Map<String, _CachedVideoInfo> _infoCache = {};

  /// Cache TTL duration.
  static const _cacheTtl = Duration(minutes: 30);

  /// User-Agent header to avoid being blocked.
  static const _userAgent = 'Mozilla/5.0 (compatible; AnytimePodcastPlayer/1.0)';

  /// Fallback Invidious instances to try (full URLs).
  static const _fallbackInvidiousInstances = [
    'https://inv.nadeko.net',
    'https://yewtu.be',
  ];

  /// Regex for extracting YouTube video IDs from URLs.
  static final _videoIdRegExp = RegExp(
    r'(?:https?://)?'
    r'(?:www\.|m\.|music\.)?'
    r'(?:youtube\.com/(?:watch\?.*v=|embed/|shorts/|live/)|youtu\.be/)'
    r'([A-Za-z0-9_-]{11})'
    r'(?:[?&/].*)?$',
  );

  /// Regex for detecting a bare channel ID.
  static final _channelIdRegExp = RegExp(r'^UC[A-Za-z0-9_-]{22}$');

  Map<String, String> get _defaultHeaders => {
        'User-Agent': _userAgent,
      };

  MobileYouTubeService({
    this.invidiousBaseUrl = 'https://invidious.fdn.fr',
    this.defaultQuality = YouTubeQuality.low,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  String extractVideoIdFromUrl(String url) {
    // Already a bare video ID?
    if (url.length == 11 && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) {
      return url;
    }

    final match = _videoIdRegExp.firstMatch(url);
    if (match != null) {
      return match.group(1)!;
    }

    // If no match, return the input as-is (may already be a video ID in
    // non-standard format — caller should handle failures).
    return url;
  }

  @override
  Future<String?> resolveChannelId(String input) async {
    // Already a channel ID?
    if (_channelIdRegExp.hasMatch(input.trim())) {
      return input.trim();
    }

    // Extract handle from URL or raw handle.
    var handle = input.trim();

    // If it's a URL, extract the @handle part.
    final urlMatch = RegExp(r'youtube\.com/(@[A-Za-z0-9_.-]+)').firstMatch(handle);
    if (urlMatch != null) {
      handle = urlMatch.group(1)!;
    }

    // If it's a /channel/UC... URL, extract directly.
    if (!handle.startsWith('@')) {
      final channelMatch = RegExp(r'youtube\.com/channel/(UC[A-Za-z0-9_-]{22})').firstMatch(input);
      if (channelMatch != null) {
        return channelMatch.group(1)!;
      }
      return null;
    }

    // Primary: fetch the channel page and extract the channel ID from HTML.
    // YouTube always includes the channel ID in the page source.
    _log.fine('Fetching channel page to extract ID: $handle');
    try {
      final result = await _scrapeChannelId(handle);
      if (result != null) return result;
    } catch (e) {
      _log.warning('Channel page scraping failed for $handle: $e');
    }

    // Fallback: try Invidious search across multiple instances.
    final channelSlug = handle.substring(1);
    final instances = <String>[invidiousBaseUrl, ..._fallbackInvidiousInstances];
    for (final instance in instances) {
      try {
        final result = await _tryInvidiousSearch(instance, channelSlug, handle);
        if (result != null) return result;
      } catch (_) {
        // Try next instance.
      }
    }

    return null;
  }

  /// Fetches the YouTube channel page and extracts the channel ID from the HTML.
  Future<String?> _scrapeChannelId(String handle) async {
    final pageUrl = 'https://www.youtube.com/$handle';
    _log.fine('Scraping channel page: $pageUrl');

    final response = await _httpClient
        .get(Uri.parse(pageUrl), headers: _defaultHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      _log.warning('Channel page returned ${response.statusCode}');
      return null;
    }

    final body = response.body;

    // Method 1: externalId in ytInitialData JSON (most reliable).
    final extIdMatch = RegExp(r'"externalId"\s*:\s*"(UC[A-Za-z0-9_-]{22})"').firstMatch(body);
    if (extIdMatch != null) {
      _log.fine('Extracted channel ID from externalId: ${extIdMatch.group(1)}');
      return extIdMatch.group(1)!;
    }

    // Method 2: channelId in ytInitialData.
    final chIdMatch = RegExp(r'"channelId"\s*:\s*"(UC[A-Za-z0-9_-]{22})"').firstMatch(body);
    if (chIdMatch != null) {
      _log.fine('Extracted channel ID from channelId: ${chIdMatch.group(1)}');
      return chIdMatch.group(1)!;
    }

    // Method 3: canonical URL.
    final canonicalMatch = RegExp(r'<link\s+rel="canonical"\s+href="[^"]*channel/(UC[A-Za-z0-9_-]{22})"').firstMatch(body);
    if (canonicalMatch != null) {
      _log.fine('Extracted channel ID from canonical: ${canonicalMatch.group(1)}');
      return canonicalMatch.group(1)!;
    }

    // Method 4: og:url meta tag.
    final ogMatch = RegExp(r'<meta\s+property="og:url"\s+content="[^"]*channel/(UC[A-Za-z0-9_-]{22})"').firstMatch(body);
    if (ogMatch != null) {
      _log.fine('Extracted channel ID from og:url: ${ogMatch.group(1)}');
      return ogMatch.group(1)!;
    }

    // Method 5: itemprop channelId.
    final itemMatch = RegExp(r'<meta\s+itemprop="channelId"\s+content="(UC[A-Za-z0-9_-]{22})"').firstMatch(body);
    if (itemMatch != null) {
      _log.fine('Extracted channel ID from itemprop: ${itemMatch.group(1)}');
      return itemMatch.group(1)!;
    }

    _log.warning('Could not extract channel ID from page. Body length: ${body.length}');
    return null;
  }

  /// Tries to resolve a channel handle via an Invidious instance's search API.
  Future<String?> _tryInvidiousSearch(String baseUrl, String channelSlug, String handle) async {
    final searchUrl = '$baseUrl/api/v1/search?q=$channelSlug&type=channel';
    _log.fine('Invidious search: $searchUrl');

    final response = await _httpClient
        .get(Uri.parse(searchUrl), headers: _defaultHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final results = jsonDecode(response.body) as List<dynamic>;
      for (final result in results) {
        if (result is Map<String, dynamic>) {
          final authorId = result['authorId'] as String?;
          final authorUrl = result['authorUrl'] as String?;
          final resultHandle = authorUrl?.split('/').last;
          if (resultHandle == handle && authorId != null) {
            _log.fine('Resolved $handle → $authorId via $baseUrl');
            return authorId;
          }
        }
      }
      if (results.isNotEmpty && results.first is Map<String, dynamic>) {
        final first = results.first as Map<String, dynamic>;
        final authorId = first['authorId'] as String?;
        if (authorId != null) {
          _log.fine('Resolved $handle → $authorId (first from $baseUrl)');
          return authorId;
        }
      }
    }
    return null;
  }

  @override
  Future<String> extractAudioUrl(
    String videoId, {
    YouTubeQuality quality = YouTubeQuality.low,
  }) async {
    // Check cache.
    final cached = _urlCache[videoId];
    if (cached != null && !cached.isExpired) {
      _log.fine('Cache hit for video $videoId');
      return cached.url;
    }

    // Primary: youtube_explode_dart (direct, no third-party service needed).
    try {
      final url = await _extractWithYoutubeExplode(videoId, quality);
      if (url != null) {
        _urlCache[videoId] = _CachedUrl(url: url, expiresAt: DateTime.now().add(_cacheTtl));
        return url;
      }
    } catch (e) {
      _log.warning('youtube_explode_dart failed for $videoId: $e');
    }

    // Fallback: Invidious API.
    try {
      final url = await _extractWithInvidious(videoId, quality);
      if (url != null) {
        _urlCache[videoId] = _CachedUrl(url: url, expiresAt: DateTime.now().add(_cacheTtl));
        return url;
      }
    } catch (e) {
      _log.warning('Invidious fallback failed for $videoId: $e');
    }

    throw Exception('No audio formats found for video $videoId');
  }

  /// Extracts audio URL using youtube_explode_dart.
  Future<String?> _extractWithYoutubeExplode(String videoId, YouTubeQuality quality) async {
    _log.fine('Extracting audio via youtube_explode_dart for $videoId');
    _youtubeExplode ??= yt.YoutubeExplode();

    final manifest = await _youtubeExplode!.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly;

    if (audioStreams.isEmpty) return null;

    // Sort by bitrate ascending (lowest first).
    final sorted = audioStreams.toList()..sort((a, b) => a.bitrate.compareTo(b.bitrate));

    yt.AudioStreamInfo selected;
    switch (quality) {
      case YouTubeQuality.low:
        selected = sorted.first;
      case YouTubeQuality.high:
        selected = sorted.last;
      case YouTubeQuality.medium:
        selected = sorted.length >= 2 ? sorted[sorted.length ~/ 2] : sorted.last;
    }

    _log.fine('Selected ${selected.audioCodec} @ ${selected.bitrate.bitsPerSecond}bps from youtube_explode_dart');
    return selected.url.toString();
  }

  /// Extracts audio URL using Invidious API (fallback).
  Future<String?> _extractWithInvidious(String videoId, YouTubeQuality quality) async {
    _log.fine('Extracting audio via Invidious for $videoId');
    final info = await _getVideoInfoInvidious(videoId);
    if (info == null || info.formats.isEmpty) return null;

    final format = info.formatForQuality(quality);
    return format?.url;
  }

  @override
  Future<YouTubeVideoInfo?> getVideoInfo(String videoId) async {
    // Check cache first.
    final cached = _infoCache[videoId];
    if (cached != null && !cached.isExpired) {
      _log.fine('Video info cache hit for $videoId');
      return cached.info;
    }

    // Primary: youtube_explode_dart.
    try {
      final info = await _getVideoInfoExplode(videoId);
      if (info != null) {
        _infoCache[videoId] = _CachedVideoInfo(info: info, expiresAt: DateTime.now().add(_cacheTtl));
        return info;
      }
    } catch (e) {
      _log.warning('youtube_explode_dart getVideoInfo failed: $e');
    }

    // Fallback: Invidious.
    try {
      final info = await _getVideoInfoInvidious(videoId);
      if (info != null) {
        _infoCache[videoId] = _CachedVideoInfo(info: info, expiresAt: DateTime.now().add(_cacheTtl));
        return info;
      }
    } catch (e) {
      _log.warning('Invidious getVideoInfo failed: $e');
    }

    return null;
  }

  /// Gets video info via youtube_explode_dart.
  Future<YouTubeVideoInfo?> _getVideoInfoExplode(String videoId) async {
    _youtubeExplode ??= yt.YoutubeExplode();
    final video = await _youtubeExplode!.videos.get(videoId);
    final manifest = await _youtubeExplode!.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly.toList()..sort((a, b) => a.bitrate.compareTo(b.bitrate));

    final formats = audioStreams.map((s) => YouTubeAudioFormat(
          url: s.url.toString(),
          bitrate: s.bitrate.bitsPerSecond,
          codec: s.audioCodec,
          contentLength: s.size.totalBytes,
          mimeType: s.audioCodec == 'opus' ? 'audio/webm' : 'audio/mp4',
        )).toList();

    return YouTubeVideoInfo(
      videoId: videoId,
      duration: video.duration ?? Duration.zero,
      formats: formats,
      thumbnailUrl: video.thumbnails.highResUrl,
      title: video.title,
    );
  }

  /// Gets video info via Invidious API (fallback).
  Future<YouTubeVideoInfo?> _getVideoInfoInvidious(String videoId) async {
    try {
      final apiUrl = '$invidiousBaseUrl/api/v1/videos/$videoId';
      _log.fine('Fetching video info from $apiUrl');

      final response = await _httpClient.get(
        Uri.parse(apiUrl),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        _log.warning('Video $videoId not found on Invidious instance');
        return null;
      }

      if (response.statusCode != 200) {
        _log.warning('Invidious API returned ${response.statusCode} for video $videoId');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Parse audio formats.
      final formats = <YouTubeAudioFormat>[];
      final adaptiveFormats = json['adaptiveFormats'] as List<dynamic>?;
      final formatStreams = json['formatStreams'] as List<dynamic>?;

      // Prefer adaptiveFormats (DASH) for audio-only streams.
      final allFormats = <dynamic>[
        ...?adaptiveFormats,
        ...?formatStreams,
      ];

      for (final fmt in allFormats) {
        if (fmt is! Map<String, dynamic>) continue;

        final type = fmt['type'] as String? ?? '';
        // 'type' looks like "audio/mp4; codecs=\"mp4a.40.2\""
        final isAudio = type.startsWith('audio/') ||
            (fmt['audioQuality'] != null) ||
            (fmt['bitrate'] != null && (fmt['container'] == null || type.contains('audio')));

        if (!isAudio) continue;

        final url = fmt['url'] as String?;
        if (url == null || url.isEmpty) continue;

        final bitrateStr = (fmt['bitrate'] as String?) ?? '0';
        final bitrate = int.tryParse(bitrateStr) ?? 0;
        final codec = _extractCodec(type);
        final contentLengthStr = (fmt['contentLength'] as String?) ?? '0';
        final contentLength = int.tryParse(contentLengthStr) ?? 0;

        formats.add(YouTubeAudioFormat(
          url: url,
          bitrate: bitrate,
          codec: codec,
          contentLength: contentLength,
          mimeType: type,
        ));
      }

      // Sort by bitrate ascending.
      formats.sort((a, b) => a.bitrate.compareTo(b.bitrate));

      // Parse duration.
      final durationSeconds = (json['lengthSeconds'] as num?)?.toInt() ?? 0;
      final duration = Duration(seconds: durationSeconds);

      // Get best thumbnail.
      final videoThumbnails = json['videoThumbnails'] as List<dynamic>?;
      String? thumbnailUrl;
      if (videoThumbnails != null && videoThumbnails.isNotEmpty) {
        // Pick medium quality thumbnail.
        final thumb = videoThumbnails.length > 1 ? videoThumbnails[1] : videoThumbnails[0];
        thumbnailUrl = (thumb as Map<String, dynamic>)['url'] as String?;
      }

      final info = YouTubeVideoInfo(
        videoId: videoId,
        duration: duration,
        formats: formats,
        thumbnailUrl: thumbnailUrl,
        title: json['title'] as String?,
      );

      // Cache the result.
      _infoCache[videoId] = _CachedVideoInfo(
        info: info,
        expiresAt: DateTime.now().add(_cacheTtl),
      );

      return info;
    } catch (e, stack) {
      _log.warning('Failed to fetch video info for $videoId: $e', e, stack);
      return null;
    }
  }

  /// Extracts the codec name from a MIME type string.
  static String _extractCodec(String mimeType) {
    final codecMatch = RegExp(r'codecs="?([^",]+)').firstMatch(mimeType);
    if (codecMatch != null) {
      return codecMatch.group(1)!;
    }
    // Fallback: e.g. "audio/mp4" → "mp4a", "audio/webm" → "opus"
    if (mimeType.contains('webm')) return 'opus';
    if (mimeType.contains('mp4')) return 'mp4a';
    return mimeType;
  }

  /// Clears expired cache entries. Called periodically or on dispose.
  void clearExpiredCache() {
    _urlCache.removeWhere((_, v) => v.isExpired);
    _infoCache.removeWhere((_, v) => v.isExpired);
  }

  /// Disposes the HTTP client, YoutubeExplode, and clears caches.
  void dispose() {
    _urlCache.clear();
    _infoCache.clear();
    _youtubeExplode?.close();
    _httpClient.close();
  }
}

/// Internal cache entry for resolved audio URLs.
class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Internal cache entry for video info.
class _CachedVideoInfo {
  final YouTubeVideoInfo info;
  final DateTime expiresAt;

  _CachedVideoInfo({required this.info, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
