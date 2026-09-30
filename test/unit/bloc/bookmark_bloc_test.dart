// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/state/bookmark_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/fake_repository.dart';

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

    test('states carry the scope of the query that produced them', () async {
      final scopedRepository = FakeRepository();
      await scopedRepository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        episodeTitle: 'Episode 1',
        positionMs: 1000,
        createdAt: DateTime(2026, 7, 1),
      ));
      await scopedRepository.saveBookmark(Bookmark(
        episodeGuid: 'ep-2',
        episodeTitle: 'Episode 2',
        positionMs: 2000,
        createdAt: DateTime(2026, 7, 2),
      ));

      final bloc = BookmarkBloc(repository: scopedRepository);
      addTearDown(() => bloc.dispose());

      final states = <BlocState<List<Bookmark>>>[];
      bloc.state.listen(states.add);

      bloc.event(BookmarkFetchAllEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      var state = states.last as BookmarkListState;
      expect(state.scope, BookmarkScope.all);
      expect(state.results!.length, 2);

      bloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: 'ep-1'));
      await Future.delayed(const Duration(milliseconds: 100));

      state = states.last as BookmarkListState;
      expect(state.scope, BookmarkScope.episode);
      expect(state.episodeGuid, 'ep-1');
      expect(state.results!.length, 1);

      // Creating a bookmark while the episode scope is active must not replace
      // the state with an all-scope list.
      bloc.event(BookmarkFetchAllEvent());
      await Future.delayed(const Duration(milliseconds: 100));
      expect((states.last as BookmarkListState).scope, BookmarkScope.all);
    });

    test('delete refreshes both the all scope and the active episode scope', () async {
      final scopedRepository = FakeRepository();
      await scopedRepository.saveBookmark(Bookmark(
        episodeGuid: 'ep-1',
        episodeTitle: 'Episode 1',
        positionMs: 1000,
        createdAt: DateTime(2026, 7, 1),
      ));
      await scopedRepository.saveBookmark(Bookmark(
        episodeGuid: 'ep-2',
        episodeTitle: 'Episode 2',
        positionMs: 2000,
        createdAt: DateTime(2026, 7, 2),
      ));

      final bloc = BookmarkBloc(repository: scopedRepository);
      addTearDown(() => bloc.dispose());

      final states = <BlocState<List<Bookmark>>>[];
      bloc.state.listen(states.add);

      bloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: 'ep-1'));
      await Future.delayed(const Duration(milliseconds: 100));

      final episodeScoped = states.last as BookmarkListState;
      expect(episodeScoped.scope, BookmarkScope.episode);

      bloc.event(BookmarkDeleteEvent(bookmark: episodeScoped.results!.first));
      await Future.delayed(const Duration(milliseconds: 100));

      // The bookmarks overview (all scope) must also be refreshed, or a
      // dismissed row would remain in its list.
      final allStates = states.whereType<BookmarkListState>().where((s) => s.scope == BookmarkScope.all);
      expect(allStates, isNotEmpty);
      expect(allStates.last.results!.length, 1);

      final episodeStates = states.whereType<BookmarkListState>().where((s) => s.scope == BookmarkScope.episode);
      expect(episodeStates.last.results, isEmpty);
    });
  });
}
