// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@Skip('SQLite tests require a real device/emulator — sqflite needs native SQLite')
library;

import 'package:anytime/entities/downloadable.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/repository/sqlite/sqlite_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider.dart';

void main() {
  MockPathProvder mockPath;
  SqliteRepository? persistenceService;

  late Podcast podcast1;
  late Podcast podcast2;

  setUp(() async {
    mockPath = MockPathProvder();
    PathProviderPlatform.instance = mockPath;
    persistenceService = SqliteRepository(databaseName: 'test_${DateTime.now().microsecondsSinceEpoch}.sqlite');

    podcast1 = Podcast(
        title: 'Podcast 1', description: '1st p1', guid: 'http://p1.com', link: 'http://p1.com', url: 'http://p1.com');

    podcast2 = Podcast(
        title: 'Podcast 2', description: '2nd p1', guid: 'http://p2.com', link: 'http://p2.com', url: 'http://p2.com');
  });

  tearDown(() async {
    await persistenceService!.close();
    persistenceService = null;
  });

  test('Fetch p1 with non-existent ID', () async {
    var result = await persistenceService!.findPodcastById(123);
    expect(result, null);
  });

  group('Podcast creation and retrieval', () {
    test('Create and save a single Podcast without episodes', () async {
      await persistenceService!.savePodcast(podcast1);
      expect(true, podcast1.id! > 0);
    });

    test('Retrieve existing Podcasts with episodes and unplayed count', () async {
      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, played: true),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, played: false),
      ];

      podcast2.episodes = <Episode>[
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast2.guid, podcast: podcast2.title, played: true),
        Episode(guid: 'EP004', title: 'Episode 4', pguid: podcast2.guid, podcast: podcast2.title, played: true),
        Episode(guid: 'EP005', title: 'Episode 5', pguid: podcast2.guid, podcast: podcast2.title, played: false),
        Episode(guid: 'EP006', title: 'Episode 6', pguid: podcast2.guid, podcast: podcast2.title, played: false),
      ];

      await persistenceService!.savePodcast(podcast1);
      await persistenceService!.savePodcast(podcast2);

      var p1 = (await persistenceService!.findPodcastById(podcast1.id!))!;
      var p2 = (await persistenceService!.findPodcastById(podcast2.id!))!;

      expect(p1 == podcast1, true);
      expect(p2 == podcast2, true);
      expect(listEquals(p1.episodes, podcast1.episodes), true);
      expect(listEquals(p2.episodes, podcast2.episodes), true);

      final unplayedCount = (await persistenceService!.findEpisodeCountByPodcast(filter: PodcastEpisodeFilter.played));
      expect(unplayedCount[podcast1.guid], 1);
      expect(unplayedCount[podcast2.guid], 2);

      final startedCount = (await persistenceService!.findEpisodeCountByPodcast(filter: PodcastEpisodeFilter.started));
      expect(startedCount[podcast1.guid], 1);
      expect(startedCount[podcast2.guid], 1);
    });
  });

  group('Saving, updating and retrieving episodes', () {
    test('Subscribe to podcasts and retrieve', () async {
      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title),
      ];

      await persistenceService!.savePodcast(podcast1);
      var p1 = await persistenceService!.findPodcastById(podcast1.id!);

      expect(p1, isNotNull);
      expect(p1!.episodes.length, 2);
    });

    test('Delete all episodes for a p1', () async {
      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title),
      ];

      await persistenceService!.savePodcast(podcast1);

      var episodes = await persistenceService!.findEpisodesByPodcastGuid(podcast1.guid);
      expect(episodes.length, 2);

      await persistenceService!.deleteEpisodes(episodes);
      episodes = await persistenceService!.findEpisodesByPodcastGuid(podcast1.guid);
      expect(episodes.length, 0);
    });
  });

  group('Saving, updating and retrieving downloaded episodes', () {
    test('Fetch downloaded episodes', () async {
      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            downloadState: DownloadState.downloaded,
            downloadPercentage: 100),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title),
      ];

      await persistenceService!.savePodcast(podcast1);

      var downloads = await persistenceService!.findDownloads();
      expect(downloads.length, 1);
      expect(downloads[0].guid, 'EP001');
    });

    test('Delete downloaded episodes', () async {
      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            downloadState: DownloadState.downloaded,
            downloadPercentage: 100),
      ];

      await persistenceService!.savePodcast(podcast1);
      var downloads = await persistenceService!.findDownloads();
      expect(downloads.length, 1);

      await persistenceService!.deleteEpisode(downloads[0]);
      downloads = await persistenceService!.findDownloads();
      expect(downloads.length, 0);
    });

    test('Test episode transcript read/write', () async {
      final episode = Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title);

      podcast1.episodes = [episode];
      await persistenceService!.savePodcast(podcast1);

      var transcript = Transcript(subtitles: [
        Subtitle(data: 'Hello', speaker: 'Speaker 1', start: Duration.zero, end: const Duration(seconds: 5), index: 0),
      ]);

      transcript = await persistenceService!.saveTranscript(transcript);
      expect(transcript.id, isNotNull);

      episode.transcriptId = transcript.id;
      await persistenceService!.saveEpisode(episode);

      var loadedEpisode = await persistenceService!.findEpisodeById(episode.id!);
      expect(loadedEpisode, isNotNull);
      expect(loadedEpisode!.transcriptId, transcript.id);
    });
  });
}
