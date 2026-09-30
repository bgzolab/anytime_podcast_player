// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/chapter.dart';
import 'package:anytime/entities/downloadable.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/person.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/repository/sqlite/sqlite_repository.dart';
import 'package:anytime/state/episode_state.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider.dart';

void main() {
  // Run SQLite on the Dart VM (desktop tests and CI) instead of a device.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  MockPathProvder mockPath;
  SqliteRepository? persistenceService;
  late String databaseName;

  late Podcast podcast1;
  late Podcast podcast2;

  setUp(() async {
    mockPath = MockPathProvder();
    PathProviderPlatform.instance = mockPath;
    databaseName = 'test_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    persistenceService = SqliteRepository(databaseName: databaseName);

    podcast1 = Podcast(
        title: 'Podcast 1', description: '1st p1', guid: 'http://p1.com', link: 'http://p1.com', url: 'http://p1.com');

    podcast2 = Podcast(
        title: 'Podcast 2', description: '2nd p1', guid: 'http://p2.com', link: 'http://p2.com', url: 'http://p2.com');
  });

  tearDown(() async {
    await persistenceService!.close();
    persistenceService = null;

    // SQLite keeps sidecar files; remove them with the database.
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('${Directory.systemTemp.path}/$databaseName$suffix');

      if (file.existsSync()) {
        file.deleteSync();
      }
    }
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
      // Fixtures are in newest-first order, matching the default episode sort
      // applied by the repository when it loads a podcast.
      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP002',
            title: 'Episode 2',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            position: 100,
            played: true,
            publicationDate: DateTime.now().subtract(const Duration(hours: 2))),
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            played: false,
            publicationDate: DateTime.now().subtract(const Duration(hours: 3))),
      ];

      podcast2.episodes = <Episode>[
        Episode(
            guid: 'EP004',
            title: 'Episode 4',
            pguid: podcast2.guid,
            podcast: podcast2.title,
            position: 100,
            played: true,
            publicationDate: DateTime.now().subtract(const Duration(days: 1))),
        Episode(
            guid: 'EP003',
            title: 'Episode 3',
            pguid: podcast2.guid,
            podcast: podcast2.title,
            played: true,
            publicationDate: DateTime.now().subtract(const Duration(days: 2))),
        Episode(
            guid: 'EP002',
            title: 'Episode 2',
            pguid: podcast2.guid,
            podcast: podcast2.title,
            played: false,
            publicationDate: DateTime.now().subtract(const Duration(days: 3))),
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast2.guid,
            podcast: podcast2.title,
            played: false,
            publicationDate: DateTime.now().subtract(const Duration(days: 4))),
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

  group('Bookmark persistence', () {
    test('Bookmarks are sorted numerically by position', () async {
      await persistenceService!.saveBookmark(Bookmark(
        episodeGuid: 'ep-bookmark',
        episodeTitle: 'Episode 1',
        podcastName: 'Podcast 1',
        positionMs: 10000,
        createdAt: DateTime(2026, 7, 18),
      ));
      await persistenceService!.saveBookmark(Bookmark(
        episodeGuid: 'ep-bookmark',
        episodeTitle: 'Episode 1',
        podcastName: 'Podcast 1',
        positionMs: 9000,
        createdAt: DateTime(2026, 7, 18),
      ));

      final bookmarks = await persistenceService!.findBookmarksByEpisodeGuid('ep-bookmark');

      // 9000 must come before 10000 — a lexicographic comparison would invert
      // these ("10000" < "9000").
      expect(bookmarks.map((b) => b.positionMs).toList(), [9000, 10000]);
    });

    test('saveBookmark updates an existing bookmark by id', () async {
      final saved = await persistenceService!.saveBookmark(Bookmark(
        episodeGuid: 'ep-update',
        episodeTitle: 'Episode 1',
        positionMs: 1000,
        note: 'first',
        createdAt: DateTime(2026, 7, 18),
      ));

      await persistenceService!.saveBookmark(Bookmark(
        id: saved.id,
        episodeGuid: 'ep-update',
        episodeTitle: 'Episode 1',
        positionMs: 1000,
        note: 'updated',
        createdAt: DateTime(2026, 7, 18),
      ));

      final bookmarks = await persistenceService!.findBookmarksByEpisodeGuid('ep-update');

      expect(bookmarks.length, 1);
      expect(bookmarks.first.note, 'updated');
    });

    test('deleting an episode removes its bookmarks', () async {
      await persistenceService!.saveBookmark(Bookmark(
        episodeGuid: 'EP001',
        episodeTitle: 'Episode 1',
        positionMs: 1000,
        createdAt: DateTime(2026, 7, 18),
      ));

      final episode =
          await persistenceService!.saveEpisode(Episode(guid: 'EP001', podcast: 'Podcast 1', title: 'Episode 1'));

      await persistenceService!.deleteEpisode(episode);

      expect(await persistenceService!.findBookmarksByEpisodeGuid('EP001'), isEmpty);
    });

    test('deleting a podcast removes its episodes and bookmarks', () async {
      await persistenceService!.saveBookmark(Bookmark(
        episodeGuid: 'EP001',
        episodeTitle: 'Episode 1',
        podcastGuid: podcast1.guid,
        podcastName: 'Podcast 1',
        positionMs: 1000,
        createdAt: DateTime(2026, 7, 18),
      ));

      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', pguid: podcast1.guid, podcast: podcast1.title, title: 'Episode 1'),
      ];

      await persistenceService!.savePodcast(podcast1);

      await persistenceService!.deletePodcast(podcast1);

      expect(await persistenceService!.findBookmarksByEpisodeGuid('EP001'), isEmpty);
      expect(await persistenceService!.findEpisodesByPodcastGuid(podcast1.guid), isEmpty);
      expect(await persistenceService!.findPodcastById(podcast1.id!), isNull);
    });
  });

  group('Timeline pagination', () {
    test('findEpisodesBefore includes episodes sharing the cursor date', () async {
      final newest = DateTime(2026, 7, 18, 12);
      final shared = newest.subtract(const Duration(minutes: 1));

      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: newest),
        Episode(
            guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: shared),
        Episode(
            guid: 'EP003', title: 'Episode 3', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: shared),
      ];

      await persistenceService!.savePodcast(podcast1);

      // First page: newest episode plus one of the two sharing a date.
      final page1 = await persistenceService!.findEpisodesBefore(DateTime.now(), limit: 2);
      expect(page1.length, 2);
      expect(page1.first.guid, 'EP001');

      // The cursor sits on the shared date; the next page must still see the
      // episodes with that exact timestamp (inclusive bound), otherwise they
      // would be unreachable.
      final cursor = page1.last.publicationDate!;
      final page2 = await persistenceService!.findEpisodesBefore(cursor, limit: 10);

      expect(page2.map((e) => e.guid).toSet().containsAll({'EP002', 'EP003'}), isTrue);
    });
  });

  group('Subscription metadata', () {
    test('findEpisodesBefore pages through a shared timestamp with beforeId', () async {
      final shared = DateTime(2026, 7, 20, 12);

      podcast1.episodes = <Episode>[
        for (var i = 0; i < 25; i++)
          Episode(
            guid: 'EP$i',
            title: 'Episode $i',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: shared,
          ),
        Episode(
          guid: 'OLD',
          title: 'Old episode',
          pguid: podcast1.guid,
          podcast: podcast1.title,
          publicationDate: shared.subtract(const Duration(days: 1)),
        ),
      ];

      await persistenceService!.savePodcast(podcast1);

      final page1 = await persistenceService!.findEpisodesBefore(DateTime(2026, 7, 21), limit: 20);
      expect(page1.length, 20);

      // The tie-breaker lets the remaining episodes of the shared timestamp be
      // fetched instead of repeating the first page.
      final page2 =
          await persistenceService!.findEpisodesBefore(page1.last.publicationDate!, limit: 20, beforeId: page1.last.id);

      expect(page2.length, 6);
      expect(page2.map((e) => e.guid), contains('OLD'));

      final all = <Episode>[...page1, ...page2].map((e) => e.guid).toSet();
      expect(all.length, 26);
    });

    test('subscribedDate is persisted on the first save', () async {
      final subscribedDate = DateTime(2020, 1, 1);
      podcast1.subscribedDate = subscribedDate;

      await persistenceService!.savePodcast(podcast1);

      final stored = (await persistenceService!.findPodcastById(podcast1.id!))!;
      expect(stored.subscribedDate!.millisecondsSinceEpoch, subscribedDate.millisecondsSinceEpoch);
    });
  });

  group('Unicode search', () {
    test('searchPodcasts matches case-insensitively for non-ASCII titles', () async {
      final podcast = Podcast(
        title: 'Привет мир',
        description: 'Русский подкаст',
        guid: 'http://ru.com',
        link: 'http://ru.com',
        url: 'http://ru.com',
      );

      await persistenceService!.savePodcast(podcast);

      final lowercase = await persistenceService!.searchPodcasts('привет');
      final uppercase = await persistenceService!.searchPodcasts('ПРИВЕТ');

      expect(lowercase.map((p) => p.guid), contains('http://ru.com'));
      expect(uppercase.map((p) => p.guid), contains('http://ru.com'));
    });
  });

  group('savePodcast re-subscribe', () {
    test('preserves the stored row and its user settings for an existing guid', () async {
      await persistenceService!.savePodcast(podcast1);

      final storedId = podcast1.id!;
      final subscribedDate = podcast1.subscribedDate!;

      podcast1.newEpisodes = 3;
      await persistenceService!.savePodcast(podcast1);

      // A deep link or re-subscribe passes a fresh object with the same guid
      // and no id; a plain replace would delete the stored row (and its
      // settings) and insert a new one.
      final duplicate = Podcast(
        title: 'Podcast 1',
        description: '1st p1',
        guid: podcast1.guid,
        link: podcast1.link,
        url: podcast1.url,
      );

      final saved = await persistenceService!.savePodcast(duplicate);

      expect(saved.id, storedId);
      expect(saved.subscribedDate!.millisecondsSinceEpoch, subscribedDate.millisecondsSinceEpoch);
      expect(saved.newEpisodes, 3);
      expect((await persistenceService!.subscriptions()).length, 1);
    });
  });

  group('Episode change detection', () {
    test('re-saving unchanged episodes keeps their lastUpdated timestamp', () async {
      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title),
      ];

      await persistenceService!.savePodcast(podcast1);

      final first = (await persistenceService!.findEpisodeByGuid('EP001'))!;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await persistenceService!.savePodcast(podcast1);

      final second = (await persistenceService!.findEpisodeByGuid('EP001'))!;

      // Unchanged rows are skipped, so the orphan-cleanup timestamp stays put.
      expect(second.lastUpdated!.millisecondsSinceEpoch, first.lastUpdated!.millisecondsSinceEpoch);
    });
  });

  group('Episode counts', () {
    test('findEpisodeCountByPodcastGuid honours the filter', () async {
      podcast1.episodes = <Episode>[
        Episode(guid: 'EP-NEW', title: 'New', pguid: podcast1.guid, podcast: podcast1.title),
        Episode(guid: 'EP-PLAYED', title: 'Played', pguid: podcast1.guid, podcast: podcast1.title, played: true),
        Episode(guid: 'EP-STARTED', title: 'Started', pguid: podcast1.guid, podcast: podcast1.title, position: 42),
      ];

      await persistenceService!.savePodcast(podcast1);

      expect(await persistenceService!.findEpisodeCountByPodcastGuid('http://p1.com'), 3);
      expect(
        await persistenceService!
            .findEpisodeCountByPodcastGuid('http://p1.com', filter: PodcastEpisodeFilter.notPlayed),
        2,
      );
      expect(
        await persistenceService!.findEpisodeCountByPodcastGuid('http://p1.com', filter: PodcastEpisodeFilter.played),
        1,
      );
      expect(
        await persistenceService!.findEpisodeCountByPodcastGuid('http://p1.com', filter: PodcastEpisodeFilter.started),
        1,
      );
    });
  });

  group('Queue persistence', () {
    test('saveQueue and loadQueue round-trip subscribed and ad-hoc episodes', () async {
      final adHoc = Episode(guid: 'AD-HOC', podcast: 'Search result', title: 'Ad-hoc episode');
      final subscribed = Episode(guid: 'EP001', pguid: podcast1.guid, podcast: podcast1.title, title: 'Episode 1');

      // Subscribed episodes already live in the database; saveQueue only adds
      // ad-hoc ones before recording the queue.
      podcast1.episodes = <Episode>[subscribed];
      await persistenceService!.savePodcast(podcast1);

      await persistenceService!.saveQueue([adHoc, subscribed]);

      final queue = await persistenceService!.loadQueue();

      expect(queue.map((e) => e.guid).toList(), ['AD-HOC', 'EP001']);
      expect(queue.first.podcast, 'Search result');
    });
  });

  group('Event streams', () {
    test('podcastListener emits when a podcast is saved', () async {
      final events = <Podcast>[];
      final subscription = persistenceService!.podcastListener.listen(events.add);

      addTearDown(subscription.cancel);

      await persistenceService!.savePodcast(podcast1);
      await Future<void>.delayed(Duration.zero);

      expect(events.map((p) => p.guid), contains(podcast1.guid));
    });

    test('episodeListener emits update and delete states', () async {
      final events = <EpisodeState>[];
      final subscription = persistenceService!.episodeListener.listen(events.add);

      addTearDown(subscription.cancel);

      final episode =
          await persistenceService!.saveEpisode(Episode(guid: 'EP001', podcast: podcast1.title, title: 'Episode 1'));

      await persistenceService!.deleteEpisode(episode);
      await Future<void>.delayed(Duration.zero);

      expect(events.any((state) => state is EpisodeUpdateState), isTrue);
      expect(events.any((state) => state is EpisodeDeleteState), isTrue);
    });
  });

  group('Entity round-trip', () {
    test('all episode fields survive a save/reload round-trip', () async {
      final episode = Episode(
        guid: 'EP-ROUND',
        pguid: podcast1.guid,
        podcast: podcast1.title,
        title: 'Round trip',
        description: 'Description',
        content: '<p>Content</p>',
        link: 'https://example.com/episode',
        imageUrl: 'https://example.com/art.png',
        thumbImageUrl: 'https://example.com/thumb.png',
        publicationDate: DateTime(2026, 7, 18, 9, 30),
        contentUrl: 'https://example.com/episode.mp3',
        length: 1234,
        mimeType: 'audio/mpeg',
        author: 'Author',
        season: 2,
        episode: 3,
        duration: 456,
        position: 42,
        downloadPercentage: 100,
        played: true,
        newEpisode: true,
        highlight: true,
        chaptersUrl: 'https://example.com/chapters.json',
        chapters: <Chapter>[
          Chapter(title: 'Intro', imageUrl: 'https://example.com/chapter.png', startTime: 0, endTime: 12),
        ],
        transcriptUrls: <TranscriptUrl>[
          TranscriptUrl(url: 'https://example.com/transcript.vtt', type: TranscriptFormat.vtt),
        ],
        persons: <Person>[
          Person(
              name: 'Someone',
              role: 'Host',
              group: 'Cast',
              image: 'https://example.com/person.png',
              link: 'https://example.com'),
        ],
        filepath: '/downloads',
        filename: 'episode.mp3',
        downloadTaskId: 'task-1',
        downloadState: DownloadState.downloaded,
        transcriptId: 0,
      );

      await persistenceService!.saveEpisode(episode);

      final reloaded = (await persistenceService!.findEpisodeByGuid('EP-ROUND'))!;

      // Episode equality covers every persisted field (chapters, transcripts
      // and persons included); it is also what change detection relies on.
      expect(reloaded, episode);
    });
  });
}
