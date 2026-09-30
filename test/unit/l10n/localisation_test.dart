// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/l10n/L.dart';
import 'package:anytime/l10n/messages_en.dart' as messages_en;
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/l10n/messages_all_locales.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Expected entry counts for the upstream catalogues, tied to the genre
/// constants that are submitted to the API so the two cannot drift.
final _expectedCategoryCounts = <String, int>{
  'discovery_categories_itunes': PodcastService.itunesGenres.length,
  'discovery_categories_pindex': PodcastService.podcastIndexGenres.length,
};

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
      for (final entry in _expectedCategoryCounts.entries) {
        final en = Intl.message(entry.key, locale: 'en');
        final zh = Intl.message(entry.key, locale: 'zh_Hans');

        expect(en.split(',').length, entry.value, reason: '${entry.key} English count changed');
        expect(zh.split(',').length, entry.value, reason: '${entry.key} must keep the same entry count');
      }
    });

    test('the English fallback reads the generated catalogue directly', () {
      for (final entry in _expectedCategoryCounts.entries) {
        final fallback = englishCatalogueMessage(entry.key);

        // This group only checks content and counts against the ARB-derived
        // map. The "independent of Intl global state" guard lives in
        // english_fallback_independence_test.dart (own isolate, without
        // initializeMessages).
        expect(fallback, isNotNull);
        expect(fallback, isNotEmpty);
        expect(fallback, isNot(entry.key));
        expect(fallback!.split(',').length, entry.value);
      }
    });

    test('generated English catalogue keeps the expected value shapes', () {
      for (final entry in messages_en.messages.messages.entries) {
        expect(
          entry.value,
          anyOf(isA<String>(), isA<Function>()),
          reason: 'English catalogue entry "${entry.key}" has an unexpected value type',
        );
      }

      // The category entries must stay simple messages (a String or a
      // zero-argument getter) — other shapes would silently break the English
      // fallback.
      for (final key in _expectedCategoryCounts.keys) {
        final value = messages_en.messages.messages[key];

        expect(value is String || value is String Function(), isTrue,
            reason: 'Category entry "$key" is no longer a simple message');
      }
    });
  });
}
