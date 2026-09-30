// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:anytime/repository/repository.dart';
import 'package:anytime/repository/sqlite/sqlite_repository.dart';
import 'package:anytime/services/notifications/notification_service.dart';
import 'package:anytime/services/podcast/mobile_opml_service.dart';
import 'package:anytime/services/podcast/mobile_podcast_service.dart';
import 'package:anytime/services/podcast/opml_service.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/state/opml_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_notification_service.dart';
import '../mocks/mock_path_provider.dart';
import '../mocks/mock_podcast_api.dart';
import '../mocks/mock_settings_service.dart';

void main() {
  // Run SQLite on the Dart VM (desktop tests and CI) instead of a device.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final api = MockPodcastApi();
  final mockPath = MockPathProvder();
  const dbName = 'anytime-opml.db';
  late OPMLService opmlService;
  late PodcastService podcastService;
  late NotificationService notificationService;
  late Repository repository;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = mockPath;
    repository = SqliteRepository(databaseName: dbName);
    notificationService = MockNotificationService();

    podcastService = MobilePodcastService(
      api: api,
      repository: repository,
      notificationService: notificationService,
      settingsService: MockSettingsService(),
    );

    opmlService = MobileOPMLService(podcastService: podcastService, repository: repository);
  });

  tearDown(() async {
    await repository.close();

    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('${Directory.systemTemp.path}/$dbName$suffix');

      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

  test('Load test OPML file. Single Podcast. Single episode.', () async {
    var stream = opmlService.loadOPMLFile('test_resources/opml_import_test1.opml');

    await expectLater(
        stream,
        emitsInOrder(<Matcher>[
          emits(isInstanceOf<OPMLParsingState>()),
          emits(isInstanceOf<OPMLLoadingState>()),
          emits(isInstanceOf<OPMLCompletedState>()),
        ]));

    var subs = await podcastService.subscriptions();

    expect(subs.length, 1);
    expect(subs[0].title, 'Podcast Load Test 1');
    expect(subs[0].url, 'test_resources/podcast1.rss');
  });
}
