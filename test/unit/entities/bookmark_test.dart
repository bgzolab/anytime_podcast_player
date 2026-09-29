// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bookmark', () {
    test('toMap() produces correct map', () {
      final bookmark = Bookmark(
        id: 1,
        episodeGuid: 'ep-1',
        episodeTitle: 'Test Episode',
        podcastName: 'Test Podcast',
        podcastGuid: 'pod-1',
        positionMs: 30000,
        note: 'Important moment',
        createdAt: DateTime(2026, 7, 18, 14, 30),
      );

      final map = bookmark.toMap();

      expect(map['episodeGuid'], 'ep-1');
      expect(map['episodeTitle'], 'Test Episode');
      expect(map['podcastName'], 'Test Podcast');
      expect(map['podcastGuid'], 'pod-1');
      // Stored as numbers so Sembast sorts them numerically.
      expect(map['positionMs'], 30000);
      expect(map['note'], 'Important moment');
      expect(map['createdAt'], DateTime(2026, 7, 18, 14, 30).millisecondsSinceEpoch);
    });

    test('fromMap() round-trips correctly', () {
      final original = Bookmark(
        id: 1,
        episodeGuid: 'ep-1',
        episodeTitle: 'Test Episode',
        podcastName: 'Test Podcast',
        podcastGuid: 'pod-1',
        positionMs: 30000,
        note: 'Important moment',
        createdAt: DateTime(2026, 7, 18, 14, 30),
      );

      final map = original.toMap();
      final restored = Bookmark.fromMap(original.id, map);

      expect(restored.id, original.id);
      expect(restored.episodeGuid, original.episodeGuid);
      expect(restored.episodeTitle, original.episodeTitle);
      expect(restored.podcastName, original.podcastName);
      expect(restored.podcastGuid, original.podcastGuid);
      expect(restored.positionMs, original.positionMs);
      expect(restored.note, original.note);
      expect(restored.createdAt.millisecondsSinceEpoch, original.createdAt.millisecondsSinceEpoch);
    });

    test('operator == works for equal instances', () {
      final bookmark1 = Bookmark(
        id: 1,
        episodeGuid: 'ep-1',
        positionMs: 30000,
        createdAt: DateTime(2026, 7, 18),
      );

      final bookmark2 = Bookmark(
        id: 1,
        episodeGuid: 'ep-1',
        positionMs: 30000,
        createdAt: DateTime(2026, 7, 18),
      );

      expect(bookmark1 == bookmark2, true);
      expect(bookmark1.hashCode, bookmark2.hashCode);
    });

    test('operator == works for unequal instances', () {
      final bookmark1 = Bookmark(
        id: 1,
        episodeGuid: 'ep-1',
        positionMs: 30000,
        createdAt: DateTime(2026, 7, 18),
      );

      final bookmark2 = Bookmark(
        id: 2,
        episodeGuid: 'ep-2',
        positionMs: 60000,
        createdAt: DateTime(2026, 7, 19),
      );

      expect(bookmark1 == bookmark2, false);
    });

    test('fromMap handles null createdAt gracefully', () {
      final map = <String, dynamic>{
        'episodeGuid': 'ep-1',
        'episodeTitle': null,
        'podcastName': null,
        'podcastGuid': null,
        'positionMs': '5000',
        'note': null,
        'createdAt': null,
      };

      final bookmark = Bookmark.fromMap(1, map);
      expect(bookmark.episodeGuid, 'ep-1');
      expect(bookmark.positionMs, 5000);
      expect(bookmark.createdAt, isNotNull);
    });

    test('fromMap parses string values written by earlier versions', () {
      final map = <String, dynamic>{
        'episodeGuid': 'ep-1',
        'episodeTitle': 'Test Episode',
        'podcastName': 'Test Podcast',
        'podcastGuid': 'pod-1',
        'positionMs': '9000',
        'note': null,
        'createdAt': DateTime(2026, 7, 18).millisecondsSinceEpoch.toString(),
      };

      final bookmark = Bookmark.fromMap(1, map);
      expect(bookmark.positionMs, 9000);
      expect(bookmark.createdAt.millisecondsSinceEpoch, DateTime(2026, 7, 18).millisecondsSinceEpoch);
    });
  });
}
