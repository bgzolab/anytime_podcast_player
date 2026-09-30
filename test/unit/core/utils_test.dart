// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/core/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAudioUrl', () {
    test('returns the URL unchanged when the path is already normal', () {
      const url = 'https://example.com/path/episode.mp3';

      expect(normalizeAudioUrl(url), url);
    });

    test('collapses consecutive slashes in the path', () {
      expect(normalizeAudioUrl('https://example.com//path//episode.mp3'), 'https://example.com/path/episode.mp3');
    });

    test('collapses a leading double slash after the authority', () {
      expect(normalizeAudioUrl('https://example.com//episode.m4a'), 'https://example.com/episode.m4a');
    });

    test('preserves query and fragment', () {
      expect(
        normalizeAudioUrl('https://example.com//path/episode.mp3?token=a%2Fb&x=1#t=30'),
        'https://example.com/path/episode.mp3?token=a%2Fb&x=1#t=30',
      );
    });

    test('returns the URL unchanged when it has no scheme', () {
      const url = '//cdn.example.com/a//b.mp3';

      expect(normalizeAudioUrl(url), url);
    });

    test('returns unparseable URLs unchanged', () {
      const url = 'not a url';

      expect(normalizeAudioUrl(url), url);
    });

    test('preserves percent-encoded slashes', () {
      // Uri.path and Uri.replace(path:) keep existing escape sequences, so a
      // path containing only %2F (an encoded slash) is never rewritten.
      const url = 'https://example.com/a%2F%2Fb.mp3';

      expect(normalizeAudioUrl(url), url);
    });

    test('collapses literal slashes without touching encoded ones', () {
      expect(normalizeAudioUrl('https://example.com//a%2Fb//c.mp3'), 'https://example.com/a%2Fb/c.mp3');
    });
  });
}
