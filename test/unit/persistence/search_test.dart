// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/repository/sqlite/sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider.dart';

void main() {
  // sqflite needs native SQLite — skip on desktop test runners.
  final bool skipTests = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  MockPathProvder mockPath;
  SqliteRepository? repository;

  setUp(() async {
    if (skipTests) return;
    mockPath = MockPathProvder();
    PathProviderPlatform.instance = mockPath;
    repository = SqliteRepository();
  });

  tearDown(() async {
    if (repository != null) {
      await repository!.close();
      repository = null;
    }

    var f = File('${Directory.systemTemp.path}/anytime.sqlite');

    if (f.existsSync()) {
      f.deleteSync();
    }
  });

  group('searchEpisodes', () {
    test('returns episodes with matching title', () async {
      if (skipTests) return;
      final podcast = Podcast(
        title: 'Test Podcast',
        description: 'A test podcast',
        guid: 'http://test.com',
        link: 'http://test.com',
        url: 'http://test.com',
      );
      await repository!.savePodcast(podcast);

      final episode1 = Episode(
        guid: 'http://test.com/ep1',
        title: 'Hello World Episode',
        description: 'First episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
      );
      final episode2 = Episode(
        guid: 'http://test.com/ep2',
        title: 'Another Episode',
        description: 'Second episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
      );
      await repository!.saveEpisodes([episode1, episode2]);

      final results = await repository!.searchEpisodes('hello');
      expect(results.length, 1);
      expect(results[0].title, 'Hello World Episode');
    }, skip: skipTests);

    test('returns empty list when no match', () async {
      final podcast = Podcast(
        title: 'Test Podcast',
        description: 'A test podcast',
        guid: 'http://test.com',
        link: 'http://test.com',
        url: 'http://test.com',
      );
      await repository!.savePodcast(podcast);

      final episode = Episode(
        guid: 'http://test.com/ep1',
        title: 'Hello World Episode',
        description: 'First episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
      );
      await repository!.saveEpisode(episode);

      final results = await repository!.searchEpisodes('nonexistent');
      expect(results.length, 0);
    }, skip: skipTests);

    test('case-insensitive matching', () async {
      final podcast = Podcast(
        title: 'Test Podcast',
        description: 'A test podcast',
        guid: 'http://test.com',
        link: 'http://test.com',
        url: 'http://test.com',
      );
      await repository!.savePodcast(podcast);

      final episode = Episode(
        guid: 'http://test.com/ep1',
        title: 'Hello World Episode',
        description: 'First episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
      );
      await repository!.saveEpisode(episode);

      final results = await repository!.searchEpisodes('HELLO');
      expect(results.length, 1);
      expect(results[0].title, 'Hello World Episode');
    }, skip: skipTests);
  });

  group('searchPodcasts', () {
    test('returns podcasts with matching title', () async {
      final podcast1 = Podcast(
        title: 'Tech News Daily',
        description: 'Tech news',
        guid: 'http://tech.com',
        link: 'http://tech.com',
        url: 'http://tech.com',
      );
      final podcast2 = Podcast(
        title: 'Cooking Show',
        description: 'Cooking tips',
        guid: 'http://cooking.com',
        link: 'http://cooking.com',
        url: 'http://cooking.com',
      );
      await repository!.savePodcast(podcast1);
      await repository!.savePodcast(podcast2);

      final results = await repository!.searchPodcasts('tech');
      expect(results.length, 1);
      expect(results[0].title, 'Tech News Daily');
    }, skip: skipTests);

    test('returns empty list when no match', () async {
      final podcast = Podcast(
        title: 'Tech News Daily',
        description: 'Tech news',
        guid: 'http://tech.com',
        link: 'http://tech.com',
        url: 'http://tech.com',
      );
      await repository!.savePodcast(podcast);

      final results = await repository!.searchPodcasts('nonexistent');
      expect(results.length, 0);
    }, skip: skipTests);

    test('case-insensitive matching', () async {
      final podcast = Podcast(
        title: 'Tech News Daily',
        description: 'Tech news',
        guid: 'http://tech.com',
        link: 'http://tech.com',
        url: 'http://tech.com',
      );
      await repository!.savePodcast(podcast);

      final results = await repository!.searchPodcasts('TECH');
      expect(results.length, 1);
      expect(results[0].title, 'Tech News Daily');
    }, skip: skipTests);
  });

  group('searchDownloads', () {
    test('returns downloaded episodes with matching title', () async {
      final podcast = Podcast(
        title: 'Test Podcast',
        description: 'A test podcast',
        guid: 'http://test.com',
        link: 'http://test.com',
        url: 'http://test.com',
      );
      await repository!.savePodcast(podcast);

      final episode1 = Episode(
        guid: 'http://test.com/ep1',
        title: 'Downloaded Episode',
        description: 'First episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
        downloadPercentage: 100,
      );
      final episode2 = Episode(
        guid: 'http://test.com/ep2',
        title: 'Not Downloaded Episode',
        description: 'Second episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
        downloadPercentage: 0,
      );
      await repository!.saveEpisodes([episode1, episode2]);

      final results = await repository!.searchDownloads('downloaded');
      expect(results.length, 1);
      expect(results[0].title, 'Downloaded Episode');
    }, skip: skipTests);

    test('returns empty list when no match', () async {
      final podcast = Podcast(
        title: 'Test Podcast',
        description: 'A test podcast',
        guid: 'http://test.com',
        link: 'http://test.com',
        url: 'http://test.com',
      );
      await repository!.savePodcast(podcast);

      final episode = Episode(
        guid: 'http://test.com/ep1',
        title: 'Downloaded Episode',
        description: 'First episode',
        pguid: podcast.guid,
        podcast: podcast.title,
        publicationDate: DateTime.now(),
        downloadPercentage: 100,
      );
      await repository!.saveEpisode(episode);

      final results = await repository!.searchDownloads('nonexistent');
      expect(results.length, 0);
    }, skip: skipTests);
  });

  group('searchBookmarks', () {
    test('returns bookmarks matching episode title', () async {
      final bookmark = Bookmark(
        episodeGuid: 'http://test.com/ep1',
        episodeTitle: 'Hello World Episode',
        podcastName: 'Test Podcast',
        positionMs: 60000,
        createdAt: DateTime.now(),
      );
      await repository!.saveBookmark(bookmark);

      final results = await repository!.searchBookmarks('hello');
      expect(results.length, 1);
      expect(results[0].episodeTitle, 'Hello World Episode');
    }, skip: skipTests);

    test('returns bookmarks matching podcast name', () async {
      final bookmark = Bookmark(
        episodeGuid: 'http://test.com/ep1',
        episodeTitle: 'Some Episode',
        podcastName: 'Tech News Daily',
        positionMs: 60000,
        createdAt: DateTime.now(),
      );
      await repository!.saveBookmark(bookmark);

      final results = await repository!.searchBookmarks('tech');
      expect(results.length, 1);
      expect(results[0].podcastName, 'Tech News Daily');
    }, skip: skipTests);

    test('returns bookmarks matching note', () async {
      final bookmark = Bookmark(
        episodeGuid: 'http://test.com/ep1',
        episodeTitle: 'Some Episode',
        podcastName: 'Test Podcast',
        positionMs: 60000,
        note: 'Important timestamp',
        createdAt: DateTime.now(),
      );
      await repository!.saveBookmark(bookmark);

      final results = await repository!.searchBookmarks('important');
      expect(results.length, 1);
      expect(results[0].note, 'Important timestamp');
    }, skip: skipTests);

    test('returns empty list when no match', () async {
      final bookmark = Bookmark(
        episodeGuid: 'http://test.com/ep1',
        episodeTitle: 'Some Episode',
        podcastName: 'Test Podcast',
        positionMs: 60000,
        createdAt: DateTime.now(),
      );
      await repository!.saveBookmark(bookmark);

      final results = await repository!.searchBookmarks('nonexistent');
      expect(results.length, 0);
    }, skip: skipTests);
  });
}
