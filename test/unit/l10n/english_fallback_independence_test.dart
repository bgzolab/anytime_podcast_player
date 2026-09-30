// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The English fallback must work from the generated catalogue alone.
///
/// `flutter test` runs each file in its own isolate, so the global Intl state
/// here is genuinely uninitialised: no `initializeMessages()` call is made on
/// purpose. A helper that regressed to `Intl.message(locale: 'en')` would
/// return the key instead of the catalogue and fail these tests.
void main() {
  final expectedCounts = <String, int>{
    'discovery_categories_itunes': PodcastService.itunesGenres.length,
    'discovery_categories_pindex': PodcastService.podcastIndexGenres.length,
  };

  test('both category catalogues are readable without initializeMessages', () {
    for (final entry in expectedCounts.entries) {
      final fallback = englishCatalogueMessage(entry.key);

      expect(fallback, isNotNull, reason: '${entry.key} must be available without Intl initialisation');
      expect(fallback, isNot(entry.key));
      expect(fallback!.split(',').length, entry.value);
    }
  });
}
