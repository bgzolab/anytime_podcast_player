// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/services/youtube/youtube_types.dart';

/// Abstract interface for YouTube video audio extraction.
///
/// Implementing classes handle resolving YouTube video IDs to
/// direct audio stream URLs, either through the Invidious API
/// or through a native extractor like youtube_explode_dart.
abstract class YouTubeService {
  /// Extracts a direct audio stream URL for the given [videoId].
  ///
  /// The [quality] parameter selects the desired bitrate tier.
  /// Returns the audio URL on success, or throws on failure.
  Future<String> extractAudioUrl(
    String videoId, {
    YouTubeQuality quality = YouTubeQuality.low,
  });

  /// Returns full metadata about a YouTube video including
  /// all available audio formats and their bitrates.
  Future<YouTubeVideoInfo?> getVideoInfo(String videoId);

  /// Extracts the 11-character YouTube video ID from various
  /// YouTube URL formats.
  ///
  /// Supported formats:
  /// - `https://www.youtube.com/watch?v={videoId}`
  /// - `https://youtu.be/{videoId}`
  /// - `https://www.youtube.com/embed/{videoId}`
  /// - `https://www.youtube.com/shorts/{videoId}`
  /// - `https://m.youtube.com/watch?v={videoId}`
  ///
  /// Returns the video ID, or the input unchanged if it is
  /// already an 11-character video ID.
  String extractVideoIdFromUrl(String url);

  /// Resolves a YouTube channel identifier to its channel ID.
  ///
  /// Accepts:
  /// - Channel ID (`UC...`) — returned as-is.
  /// - Handle (`@channelname`) — looked up via oEmbed / page scrape.
  /// - Channel URL (`youtube.com/@channelname` or `youtube.com/channel/UC...`)
  ///
  /// Returns the channel ID, or null if resolution fails.
  Future<String?> resolveChannelId(String input);
}
