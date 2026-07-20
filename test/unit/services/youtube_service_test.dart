// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/services/youtube/mobile_youtube_service.dart';
import 'package:anytime/services/youtube/youtube_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MobileYouTubeService service;

  setUp(() {
    service = MobileYouTubeService();
  });

  tearDown(() {
    service.dispose();
  });

  group('extractVideoIdFromUrl', () {
    test('standard watch URL', () {
      expect(
        service.extractVideoIdFromUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('short youtu.be URL', () {
      expect(
        service.extractVideoIdFromUrl('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('embed URL', () {
      expect(
        service.extractVideoIdFromUrl('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('shorts URL', () {
      expect(
        service.extractVideoIdFromUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('mobile URL', () {
      expect(
        service.extractVideoIdFromUrl('https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('URL with extra query params', () {
      expect(
        service.extractVideoIdFromUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL...'),
        'dQw4w9WgXcQ',
      );
    });

    test('bare video ID returns as-is', () {
      expect(
        service.extractVideoIdFromUrl('dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('URL with underscore and dash in ID', () {
      expect(
        service.extractVideoIdFromUrl('https://youtu.be/abc123_-XYZ'),
        'abc123_-XYZ',
      );
    });
  });

  group('resolveChannelId', () {
    test('bare channel ID returned as-is', () async {
      final result = await service.resolveChannelId('UCXuqSBlHAE6Xw-yeJA0Tunw');
      expect(result, 'UCXuqSBlHAE6Xw-yeJA0Tunw');
    });

    test('bare channel ID with whitespace trimmed', () async {
      final result = await service.resolveChannelId('  UCXuqSBlHAE6Xw-yeJA0Tunw  ');
      expect(result, 'UCXuqSBlHAE6Xw-yeJA0Tunw');
    });
  });

  group('YouTubeQuality', () {
    test('fromValue round-trip', () {
      expect(YouTubeQuality.fromValue(0), YouTubeQuality.low);
      expect(YouTubeQuality.fromValue(1), YouTubeQuality.medium);
      expect(YouTubeQuality.fromValue(2), YouTubeQuality.high);
      expect(YouTubeQuality.low.toValue(), 0);
      expect(YouTubeQuality.medium.toValue(), 1);
      expect(YouTubeQuality.high.toValue(), 2);
    });

    test('invalid value defaults to low', () {
      expect(YouTubeQuality.fromValue(99), YouTubeQuality.low);
      expect(YouTubeQuality.fromValue(-1), YouTubeQuality.low);
    });
  });

  group('YouTubeVideoInfo.formatForQuality', () {
    test('returns first format for low quality', () {
      final formats = [
        const YouTubeAudioFormat(url: 'low', bitrate: 32000, codec: 'opus'),
        const YouTubeAudioFormat(url: 'mid', bitrate: 128000, codec: 'mp4a'),
        const YouTubeAudioFormat(url: 'high', bitrate: 256000, codec: 'mp4a'),
      ];
      final info = YouTubeVideoInfo(videoId: 'test', formats: formats);
      expect(info.formatForQuality(YouTubeQuality.low)?.url, 'low');
    });

    test('returns last format for high quality', () {
      final formats = [
        const YouTubeAudioFormat(url: 'low', bitrate: 32000, codec: 'opus'),
        const YouTubeAudioFormat(url: 'mid', bitrate: 128000, codec: 'mp4a'),
        const YouTubeAudioFormat(url: 'high', bitrate: 256000, codec: 'mp4a'),
      ];
      final info = YouTubeVideoInfo(videoId: 'test', formats: formats);
      expect(info.formatForQuality(YouTubeQuality.high)?.url, 'high');
    });

    test('returns middle format for medium quality', () {
      final formats = [
        const YouTubeAudioFormat(url: 'low', bitrate: 32000, codec: 'opus'),
        const YouTubeAudioFormat(url: 'mid', bitrate: 128000, codec: 'mp4a'),
        const YouTubeAudioFormat(url: 'high', bitrate: 256000, codec: 'mp4a'),
      ];
      final info = YouTubeVideoInfo(videoId: 'test', formats: formats);
      expect(info.formatForQuality(YouTubeQuality.medium)?.url, 'mid');
    });

    test('returns null for empty formats', () {
      final info = YouTubeVideoInfo(videoId: 'test', formats: []);
      expect(info.formatForQuality(YouTubeQuality.low), isNull);
    });

    test('only one format — all qualities return it', () {
      final formats = [
        const YouTubeAudioFormat(url: 'only', bitrate: 64000, codec: 'opus'),
      ];
      final info = YouTubeVideoInfo(videoId: 'test', formats: formats);
      expect(info.formatForQuality(YouTubeQuality.low)?.url, 'only');
      expect(info.formatForQuality(YouTubeQuality.medium)?.url, 'only');
      expect(info.formatForQuality(YouTubeQuality.high)?.url, 'only');
    });
  });
}
