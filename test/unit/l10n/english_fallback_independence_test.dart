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
  test('iTunes catalogue is readable without initializeMessages', () {
    final fallback = englishCatalogueMessage('discovery_categories_itunes');

    expect(fallback, isNotNull);
    expect(fallback, isNot('discovery_categories_itunes'));
    expect(fallback!.split(',').length, PodcastService.itunesGenres.length);
  });

  test('PodcastIndex catalogue is readable without initializeMessages', () {
    final fallback = englishCatalogueMessage('discovery_categories_pindex');

    expect(fallback, isNotNull);
    expect(fallback, isNot('discovery_categories_pindex'));
    expect(fallback!.split(',').length, PodcastService.podcastIndexGenres.length);
  });
}
