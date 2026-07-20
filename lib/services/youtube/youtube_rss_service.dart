// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/person.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/podcast_source.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as xml;

/// Parses YouTube channel RSS feeds into [Podcast] and [Episode] entities.
///
/// YouTube provides RSS feeds in ATOM format at
/// `https://www.youtube.com/feeds/videos.xml?channel_id={channelId}`.
/// Each `<entry>` represents a video and is mapped to an [Episode] with
/// a `youtube://{videoId}` placeholder content URL — the actual audio URL
/// is resolved lazily at playback/download time by [YouTubeService].
class YouTubeRssService {
  final _log = Logger('YouTubeRssService');

  final http.Client _httpClient;

  YouTubeRssService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Fetches and parses the YouTube channel RSS feed for the given [channelId].
  ///
  /// Returns a [Podcast] with `source == PodcastSource.youtube` and episodes
  /// populated from the feed entries. The channel's user-provided URL is
  /// stored as the podcast URL, while the RSS feed URL is used internally
  /// for refreshes.
  Future<Podcast> fetchChannel(String channelId) async {
    final rssUrl = _buildRssUrl(channelId);
    _log.fine('Fetching YouTube RSS from $rssUrl');

    final response = await _httpClient
        .get(Uri.parse(rssUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw YouTubeRssException(
        'Failed to fetch channel RSS: HTTP ${response.statusCode}',
      );
    }

    final document = xml.XmlDocument.parse(response.body);

    // Parse channel metadata.
    final title = _parseChannelTitle(document);
    final description = _parseChannelDescription(document);
    final author = _parseChannelAuthor(document);
    final imageUrl = _parseChannelImage(document);
    final channelUrl = _parseChannelUrl(document);

    // Parse episodes.
    final episodes = _parseEntries(document, channelId);

    final podcast = Podcast(
      guid: 'yt:$channelId',
      url: channelUrl.isNotEmpty ? channelUrl : 'https://www.youtube.com/channel/$channelId',
      link: channelUrl.isNotEmpty ? channelUrl : 'https://www.youtube.com/channel/$channelId',
      title: title,
      description: description,
      imageUrl: imageUrl,
      thumbImageUrl: imageUrl,
      copyright: author,
      episodes: episodes,
      source: PodcastSource.youtube,
      persons: author != null
          ? [Person(name: author, role: 'Host')]
          : null,
    );

    // Set the RSS feed URL for internal refresh tracking.
    podcast.etag = rssUrl;

    _log.fine('Parsed YouTube RSS: ${episodes.length} episodes for $title');
    return podcast;
  }

  /// Constructs the YouTube RSS feed URL for a channel ID.
  static String buildRssUrl(String channelId) {
    return 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
  }

  String _buildRssUrl(String channelId) => buildRssUrl(channelId);

  /// Extracts the channel title from the ATOM feed.
  String _parseChannelTitle(xml.XmlDocument doc) {
    final titleElem = doc.findAllElements('title').firstOrNull;
    // Atom feed has <title>Channel Name</title> at top level
    // and <title>Video Title</title> in each <entry>.
    // The first <title> before any <entry> is the channel title.
    final feed = doc.findAllElements('feed').firstOrNull;
    if (feed != null) {
      // Direct child <title> of <feed>
      for (final child in feed.children) {
        if (child is xml.XmlElement && child.name.local == 'title') {
          return child.innerText.trim();
        }
      }
    }
    return titleElem?.innerText.trim() ?? 'Unknown Channel';
  }

  /// Extracts the channel description (first entry's media:description as a fallback).
  String _parseChannelDescription(xml.XmlDocument doc) {
    // YouTube RSS doesn't have a channel-level description.
    // Use the author name as subtitle.
    return '';
  }

  /// Extracts the channel author name.
  String? _parseChannelAuthor(xml.XmlDocument doc) {
    final authorName = doc.findAllElements('name').firstOrNull;
    return authorName?.innerText.trim();
  }

  /// Extracts the channel thumbnail URL.
  String? _parseChannelImage(xml.XmlDocument doc) {
    // YouTube RSS doesn't have a direct channel thumbnail.
    // Use the first video's thumbnail as the channel image.
    final thumbnails = doc.findAllElements('thumbnail');
    for (final thumb in thumbnails) {
      final url = thumb.getAttribute('url');
      if (url != null && url.isNotEmpty) {
        return _normalizeUrl(url);
      }
    }
    return null;
  }

  /// Normalizes a potentially protocol-relative URL to use https.
  static String _normalizeUrl(String url) {
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Extracts the channel web URL.
  String _parseChannelUrl(xml.XmlDocument doc) {
    final authorUri = doc.findAllElements('uri').firstOrNull;
    if (authorUri != null && authorUri.innerText.trim().isNotEmpty) {
      return authorUri.innerText.trim();
    }
    // Fallback: try to find the channel link.
    final links = doc.findAllElements('link');
    for (final link in links) {
      final rel = link.getAttribute('rel');
      final href = link.getAttribute('href');
      if (rel == 'alternate' && href != null) {
        return href;
      }
    }
    return '';
  }

  /// Parses all <entry> elements into [Episode] objects.
  List<Episode> _parseEntries(xml.XmlDocument doc, String channelId) {
    final entries = doc.findAllElements('entry');
    final episodes = <Episode>[];

    for (final entry in entries) {
      try {
        final episode = _parseEntry(entry, channelId);
        if (episode != null) {
          episodes.add(episode);
        }
      } catch (e, stack) {
        _log.warning('Failed to parse YouTube RSS entry: $e', e, stack);
      }
    }

    return episodes;
  }

  /// Parses a single <entry> into an [Episode].
  Episode? _parseEntry(xml.XmlElement entry, String channelId) {
    // Extract video ID from <yt:videoId> or <id> (yt:video:VIDEO_ID).
    String? videoId;
    final videoIdElem = entry.findElements('videoId').firstOrNull;
    if (videoIdElem != null) {
      videoId = videoIdElem.innerText.trim();
    } else {
      // Fallback: parse from <id> tag.
      final idElem = entry.findElements('id').firstOrNull;
      if (idElem != null) {
        final idText = idElem.innerText.trim();
        final match = RegExp(r'yt:video:([A-Za-z0-9_-]{11})').firstMatch(idText);
        if (match != null) {
          videoId = match.group(1)!;
        }
      }
    }

    if (videoId == null || videoId.isEmpty) {
      _log.warning('Skipping entry: no video ID found');
      return null;
    }

    // Title.
    final title = entry.findElements('title').firstOrNull?.innerText.trim() ?? '';

    // Publication date.
    DateTime? publicationDate;
    final published = entry.findElements('published').firstOrNull?.innerText.trim();
    if (published != null && published.isNotEmpty) {
      publicationDate = DateTime.tryParse(published);
    }

    // Description from media:group/media:description.
    String? description;
    final mediaGroup = entry.findElements('group').firstOrNull;
    if (mediaGroup != null) {
      final mediaDesc = mediaGroup.findElements('description').firstOrNull;
      if (mediaDesc != null) {
        description = mediaDesc.innerText.trim();
      }
    }

    // Thumbnail from media:group/media:thumbnail.
    // YouTube RSS often returns protocol-relative URLs; normalize to https.
    String? imageUrl;
    if (mediaGroup != null) {
      final thumbnails = mediaGroup.findElements('thumbnail');
      for (final thumb in thumbnails) {
        final url = thumb.getAttribute('url');
        final widthStr = thumb.getAttribute('width');
        if (url != null && widthStr != null) {
          final width = int.tryParse(widthStr) ?? 0;
          if (width <= 480 || imageUrl == null) {
            imageUrl = _normalizeUrl(url);
          }
        } else if (url != null && imageUrl == null) {
          imageUrl = _normalizeUrl(url);
        }
      }
    }
    // Fallback: use YouTube's default thumbnail URL pattern.
    imageUrl ??= 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';

    // Author.
    final authorElem = entry.findElements('author').firstOrNull;
    String? authorName;
    if (authorElem != null) {
      authorName = authorElem.findElements('name').firstOrNull?.innerText.trim();
    }

    // Link to the video page.
    String? link;
    final links = entry.findElements('link');
    for (final l in links) {
      final rel = l.getAttribute('rel');
      final href = l.getAttribute('href');
      if (rel == 'alternate' && href != null) {
        link = href;
        break;
      }
    }

    // Duration from media:group/media:content or yt:duration?
    // YouTube RSS doesn't include duration; Episode.duration stays at 0.
    // It will be populated if YouTubeService.getVideoInfo() is called later.

    return Episode(
      guid: videoId,
      pguid: 'yt:$channelId',
      podcast: 'YouTube', // Will be overwritten when linked to Podcast.
      title: title,
      description: description,
      link: link,
      imageUrl: imageUrl,
      thumbImageUrl: imageUrl,
      publicationDate: publicationDate ?? DateTime.now(),
      contentUrl: 'youtube://$videoId',
      author: authorName,
      mimeType: 'audio/mp4', // Default; actual format determined at playback.
    );
  }

  /// Disposes the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}

/// Exception thrown when YouTube RSS parsing fails.
class YouTubeRssException implements Exception {
  final String message;

  YouTubeRssException(this.message);

  @override
  String toString() => 'YouTubeRssException: $message';
}
