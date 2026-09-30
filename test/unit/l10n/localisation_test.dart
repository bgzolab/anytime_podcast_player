// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/l10n/L.dart';
import 'package:anytime/l10n/messages_all_locales.dart';
import 'package:anytime/services/podcast/mobile_podcast_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('isSupportedLanguageCode', () {
    test('supports the bundled languages and zh variants', () {
      expect(isSupportedLanguageCode('en'), isTrue);
      expect(isSupportedLanguageCode('zh_Hans'), isTrue);
      expect(isSupportedLanguageCode('zh'), isTrue);
    });

    test('rejects other languages', () {
      expect(isSupportedLanguageCode('ja'), isFalse);
    });
  });

  group('normaliseZhLocaleName', () {
    test('normalises zh variants to zh_Hans', () {
      expect(normaliseZhLocaleName('zh'), 'zh_Hans');
      expect(normaliseZhLocaleName('zh_CN'), 'zh_Hans');
      expect(normaliseZhLocaleName('zh_Hans'), 'zh_Hans');
      expect(normaliseZhLocaleName('ZH_CN'), 'zh_Hans');
    });

    test('leaves other locales untouched', () {
      expect(normaliseZhLocaleName('en_GB'), 'en_GB');
    });
  });

  group('normaliseZhLocale', () {
    test('normalises Locale zh variants', () {
      expect(normaliseZhLocale(const Locale('zh')).languageCode, 'zh_Hans');
      expect(normaliseZhLocale(const Locale('zh', 'CN')).languageCode, 'zh_Hans');
      expect(normaliseZhLocale(const Locale('en')).languageCode, 'en');
    });
  });

  group('AnytimeLocalisationsDelegate', () {
    const delegate = AnytimeLocalisationsDelegate();

    test('supports the zh variants Flutter resolves', () {
      expect(delegate.isSupported(const Locale('zh')), isTrue);
      expect(delegate.isSupported(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')), isTrue);
      expect(delegate.isSupported(const Locale('zh_Hans')), isTrue);
    });

    test('rejects unsupported locales', () {
      expect(delegate.isSupported(const Locale('ja')), isFalse);
    });

    test('loads zh using the zh_Hans catalogue', () async {
      final localisations = await delegate.load(const Locale('zh'));

      expect(localisations.localeName, 'zh_Hans');
    });

    test('loads zh with a country code using the zh_Hans catalogue', () async {
      final localisations = await delegate.load(const Locale('zh', 'CN'));

      expect(localisations.localeName, 'zh_Hans');
    });
  });

  group('EmbeddedLocalisationsDelegate', () {
    final delegate = EmbeddedLocalisationsDelegate(messages: const {});

    test('supports the zh variants Flutter resolves', () {
      expect(delegate.isSupported(const Locale('zh')), isTrue);
      expect(delegate.isSupported(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')), isTrue);
    });

    test('loads zh using the zh_Hans catalogue', () async {
      final localisations = await delegate.load(const Locale('zh'));

      expect(localisations.localeName, 'zh_Hans');
    });

    test('loads zh with a country code using the zh_Hans catalogue', () async {
      final localisations = await delegate.load(const Locale('zh', 'CN'));

      expect(localisations.localeName, 'zh_Hans');
    });
  });

  group('discovery category catalogues', () {
    setUpAll(() async {
      await initializeMessages('zh_Hans');
      await initializeMessages('en');
    });

    test('zh_Hans translates the iTunes genres', () {
      final categories = Intl.message('discovery_categories_itunes', locale: 'zh_Hans');

      // A missing translation returns the key itself.
      expect(categories, isNot('discovery_categories_itunes'));
    });

    test('zh_Hans translates the PodcastIndex genres', () {
      final categories = Intl.message('discovery_categories_pindex', locale: 'zh_Hans');

      expect(categories, isNot('discovery_categories_pindex'));
    });

    test('catalogue entry counts match the expected English counts', () {
      // Single source of truth for the expected counts: when the upstream
      // catalogues gain or lose entries, update this map only.
      const expectedCounts = {
        'discovery_categories_itunes': 20,
        'discovery_categories_pindex': 113,
      };

      for (final entry in expectedCounts.entries) {
        final en = Intl.message(entry.key, locale: 'en');
        final zh = Intl.message(entry.key, locale: 'zh_Hans');

        expect(en.split(',').length, entry.value, reason: '${entry.key} English count changed');
        expect(zh.split(',').length, entry.value, reason: '${entry.key} must keep the same entry count');
      }
    });

    test('the English fallback reads the generated catalogue directly', () {
      // The helper must not depend on initializeMessages('en') having run;
      // evaluating the generated lookup directly guarantees that.
      for (final key in ['discovery_categories_itunes', 'discovery_categories_pindex']) {
        final fallback = MobilePodcastService.englishCatalogueMessage(key);

        expect(fallback, isNotNull);
        expect(fallback, isNotEmpty);
        expect(fallback, isNot(key));
        expect(fallback, Intl.message(key, locale: 'en'));
      }
    });
  });
}
