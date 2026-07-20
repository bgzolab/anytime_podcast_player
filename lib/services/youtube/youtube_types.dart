// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Audio quality level for YouTube stream extraction.
enum YouTubeQuality {
  /// Lowest available bitrate — smallest file, fastest streaming.
  low(id: 0),

  /// Medium bitrate, approximately 128kbps.
  medium(id: 1),

  /// Highest available bitrate — best quality, larger files.
  high(id: 2);

  const YouTubeQuality({required this.id});

  final int id;

  int toValue() => id;

  static YouTubeQuality fromValue(int v) {
    switch (v) {
      case 2:
        return YouTubeQuality.high;
      case 1:
        return YouTubeQuality.medium;
      default:
        return YouTubeQuality.low;
    }
  }
}

/// Describes an available audio format for a YouTube video.
class YouTubeAudioFormat {
  /// Direct URL to the audio stream.
  final String url;

  /// Bitrate in bits per second (not kbps).
  final int bitrate;

  /// Codec name, e.g. "aac", "opus", "mp4a".
  final String codec;

  /// Content length in bytes (0 if unknown).
  final int contentLength;

  /// MIME type, e.g. "audio/mp4", "audio/webm".
  final String mimeType;

  const YouTubeAudioFormat({
    required this.url,
    required this.bitrate,
    required this.codec,
    this.contentLength = 0,
    this.mimeType = '',
  });
}

/// Metadata about a YouTube video extracted before playback.
class YouTubeVideoInfo {
  /// The YouTube video ID.
  final String videoId;

  /// Duration of the video.
  final Duration duration;

  /// Available audio formats sorted by bitrate (lowest first).
  final List<YouTubeAudioFormat> formats;

  /// Thumbnail URL for the video.
  final String? thumbnailUrl;

  /// Video title (from the API response, for verification).
  final String? title;

  const YouTubeVideoInfo({
    required this.videoId,
    this.duration = Duration.zero,
    this.formats = const [],
    this.thumbnailUrl,
    this.title,
  });

  /// Returns the format matching the requested quality level.
  /// Falls back to the lowest available if the requested level is unavailable.
  YouTubeAudioFormat? formatForQuality(YouTubeQuality quality) {
    if (formats.isEmpty) return null;

    switch (quality) {
      case YouTubeQuality.low:
        return formats.first;
      case YouTubeQuality.high:
        return formats.last;
      case YouTubeQuality.medium:
        if (formats.length >= 2) {
          return formats[formats.length ~/ 2];
        }
        return formats.last;
    }
  }
}
