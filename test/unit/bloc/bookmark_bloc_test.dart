// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/state/episode_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake [Repository] that stores bookmarks in memory.
class FakeRepository extends Fake implements Repository {
  final List<Bookmark> _bookmarks = [];
  int _nextId = 1;

  @override
  Future<List<Bookmark>> findAllBookmarks() async {
    final sorted = List<Bookmark>.from(_bookmarks);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<List<Bookmark>> findBookmarksByEpisodeGuid(String episodeGuid) async {
    final filtered = _bookmarks.where((b) => b.episodeGuid == episodeGuid).toList();
    filtered.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return filtered;
  }

  @override
  Future<Bookmark> saveBookmark(Bookmark bookmark) async {
    if (bookmark.id == null) {
      bookmark.id = _nextId++;
      _bookmarks.add(bookmark);
    } else {
      final index = _bookmarks.indexWhere((b) => b.id == bookmark.id);
      if (index >= 0) {
        _bookmarks[index] = bookmark;
      } else {
        _bookmarks.add(bookmark);
      }
    }
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(Bookmark bookmark) async {
    _bookmarks.removeWhere((b) => b.id == bookmark.id);
  }

  @override
  Future<void> deleteBookmarksByEpisodeGuid(String episodeGuid) async {
    _bookmarks.removeWhere((b) => b.episodeGuid == episodeGuid);
  }

  // Unused methods required by Fake
  @override
  Future<void> close() async {}
  @override
  Future<Podcast?> findPodcastById(num id) async => null;
  @override
  Future<Podcast?> findPodcastByGuid(String guid) async => null;
  @override
  Future<Podcast> savePodcast(Podcast podcast, {bool withEpisodes = true}) async => podcast;
  @override
  Future<void> deletePodcast(Podcast podcast) async {}
  @override
  Future<List<Podcast>> subscriptions() async => [];
  @override
  Future<List<Episode>> findAllEpisodes() async => [];
  @override
  Future<List<Episode>> findEpisodesBefore(DateTime beforeDate, {int limit = 100}) async => [];
  @override
  Future<int> countEpisodesSince(DateTime sinceDate) async => 0;
  @override
  Future<Episode?> findEpisodeById(int id) async => null;
  @override
  Future<Episode?> findEpisodeByGuid(String guid) async => null;
  @override
  Future<List<Episode>> findEpisodesByPodcastGuid(String pguid,
          {PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
          PodcastEpisodeSort sort = PodcastEpisodeSort.none}) async =>
      [];
  @override
  Future<Map<String, int>> findEpisodeCountByPodcast({PodcastEpisodeFilter filter = PodcastEpisodeFilter.none}) async =>
      {};
  @override
  Future<int> findEpisodeCountByPodcastGuid(String pguid,
          {PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
          PodcastEpisodeSort sort = PodcastEpisodeSort.none}) async =>
      0;
  @override
  Future<Episode?> findEpisodeByTaskId(String taskId) async => null;
  @override
  Future<Episode?> findLatestPlayableEpisode(Podcast podcast) async => null;
  @override
  Future<Episode?> findNextUnplayedEpisode(Podcast podcast) async => null;
  @override
  Future<Episode?> findNextPlayableEpisode(Episode episode) async => null;
  @override
  Future<Episode> saveEpisode(Episode episode, [bool updateIfSame = false]) async => episode;
  @override
  Future<List<Episode>> saveEpisodes(List<Episode> episodes, [bool updateIfSame = false]) async => episodes;
  @override
  Future<void> deleteEpisode(Episode episode) async {}
  @override
  Future<void> deleteEpisodes(List<Episode> episodes) async {}
  @override
  Future<List<Episode>> findDownloadsByPodcastGuid(String pguid) async => [];
  @override
  Future<List<Episode>> findDownloads() async => [];
  @override
  Future<Transcript?> findTranscriptById(int id) async => null;
  @override
  Future<Transcript> saveTranscript(Transcript transcript) async => transcript;
  @override
  Future<void> deleteTranscriptById(int id) async {}
  @override
  Future<void> deleteTranscriptsById(List<int> id) async {}
  @override
  Future<void> saveQueue(List<Episode> episodes) async {}
  @override
  Future<List<Episode>> loadQueue() async => [];
  @override
  Stream<Podcast> get podcastListener => const Stream.empty();
  @override
  Stream<EpisodeState> get episodeListener => const Stream.empty();
}

void main() {
  group('BookmarkBloc', () {
    late FakeRepository repository;
    late BookmarkBloc bloc;

    setUp(() {
      repository = FakeRepository();
      bloc = BookmarkBloc(repository: repository);
    });

    tearDown(() {
      bloc.dispose();
    });

    final episode = Episode(
      guid: 'ep-1',
      pguid: 'pod-1',
      podcast: 'Test Podcast',
      title: 'Episode 1',
      duration: 1800,
    );

    test('BookmarkCreateEvent saves bookmark and emits populated state', () async {
      final states = <BlocState>[];
      bloc.state.listen((state) => states.add(state));

      bloc.event(BookmarkCreateEvent(
        episode: episode,
        positionMs: 30000,
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(1));
      final lastState = states.last as BlocPopulatedState<List<Bookmark>>;
      expect(lastState.results, isNotNull);
      expect(lastState.results!.length, 1);
      expect(lastState.results![0].episodeGuid, 'ep-1');
      expect(lastState.results![0].positionMs, 30000);
      expect(lastState.results![0].episodeTitle, 'Episode 1');
      expect(lastState.results![0].podcastName, 'Test Podcast');
    });

    test('BookmarkFetchByEpisodeEvent returns only matching bookmarks', () async {
      // Create bookmarks for two different episodes
      await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        positionMs: 10000,
        createdAt: DateTime(2026, 7, 1),
      ));
      await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-2',
        positionMs: 20000,
        createdAt: DateTime(2026, 7, 2),
      ));

      final states = <BlocState>[];
      bloc.state.listen((state) => states.add(state));

      bloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: 'ep-1'));

      await Future.delayed(const Duration(milliseconds: 100));

      final lastState = states.last as BlocPopulatedState<List<Bookmark>>;
      expect(lastState.results!.length, 1);
      expect(lastState.results![0].episodeGuid, 'ep-1');
    });

    test('BookmarkDeleteEvent removes bookmark and re-emits', () async {
      final bookmark = await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        positionMs: 10000,
        createdAt: DateTime(2026, 7, 1),
      ));

      // First fetch to set _currentEpisodeGuid
      final states = <BlocState>[];
      bloc.state.listen((state) => states.add(state));

      bloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: 'ep-1'));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.event(BookmarkDeleteEvent(bookmark: bookmark));
      await Future.delayed(const Duration(milliseconds: 100));

      final lastState = states.last as BlocPopulatedState<List<Bookmark>>;
      expect(lastState.results!.length, 0);
    });

    test('BookmarkFetchAllEvent returns all bookmarks sorted by date descending', () async {
      await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        positionMs: 10000,
        createdAt: DateTime(2026, 7, 1),
      ));
      await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-2',
        positionMs: 20000,
        createdAt: DateTime(2026, 7, 3),
      ));
      await repository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        positionMs: 30000,
        createdAt: DateTime(2026, 7, 2),
      ));

      final states = <BlocState>[];
      bloc.state.listen((state) => states.add(state));

      bloc.event(BookmarkFetchAllEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      final lastState = states.last as BlocPopulatedState<List<Bookmark>>;
      expect(lastState.results!.length, 3);
      // Sorted by createdAt descending
      expect(lastState.results![0].createdAt, DateTime(2026, 7, 3));
      expect(lastState.results![1].createdAt, DateTime(2026, 7, 2));
      expect(lastState.results![2].createdAt, DateTime(2026, 7, 1));
    });

    test('dispose closes subjects', () {
      final testBloc = BookmarkBloc(repository: repository);
      testBloc.dispose();
      // Should not throw
    });
  });
}
