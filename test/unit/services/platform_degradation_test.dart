// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/entities/episode.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/services/download/download_manager.dart';
import 'package:anytime/services/download/mobile_download_manager.dart';
import 'package:anytime/services/download/mobile_download_service.dart';
import 'package:anytime/services/notifications/mobile_notification_service.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _MockRepository extends Mock implements Repository {}

class _MockPodcastService extends Mock implements PodcastService {}

class _FakeDownloadManager extends DownloadManager {
  final _progress = StreamController<DownloadProgress>.broadcast();

  @override
  bool get supported => false;

  @override
  Stream<DownloadProgress> get downloadProgress => _progress.stream;

  @override
  Future<String?> enqueueTask(String url, String downloadPath, String fileName) async => null;

  @override
  void dispose() => _progress.close();
}

/// Verifies the graceful degradation on platforms without the notification and
/// download plugins (e.g. Windows): no exceptions, safe return values and no
/// side effects before failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification service on an unsupported platform', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reports unsupported and returns safe values', () async {
      final service = MobileNotificationService();

      expect(service.supported, isFalse);
      expect(await service.isAllowed(), isFalse);
      expect(await service.requestPermissionsIfNotGranted(), isFalse);
      expect(await service.createRefreshNotification(), isFalse);

      // Must not throw.
      await service.clearRefreshNotification();
    });
  });

  group('Download manager on an unsupported platform', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reports unsupported and does not enqueue tasks', () async {
      final manager = MobileDownloaderManager();

      expect(manager.supported, isFalse);
      expect(await manager.enqueueTask('https://example.com/episode.mp3', '/tmp', 'episode.mp3'), isNull);

      manager.dispose();
    });
  });

  group('Download service on an unsupported platform', () {
    test('short-circuits before chapters, transcripts or storage work', () async {
      final manager = _FakeDownloadManager();
      final podcastService = _MockPodcastService();
      final repository = _MockRepository();

      final service = MobileDownloadService(
        repository: repository,
        downloadManager: manager,
        podcastService: podcastService,
      );

      final episode = Episode(
        guid: 'ep-1',
        podcast: 'Test Podcast',
        title: 'Episode 1',
        chaptersUrl: 'https://example.com/chapters.json',
      );

      expect(service.supported, isFalse);
      expect(await service.downloadEpisode(episode), isFalse);

      // No chapters/transcripts were fetched and nothing was persisted.
      verifyZeroInteractions(podcastService);
      verifyZeroInteractions(repository);

      service.dispose();
    });
  });
}
