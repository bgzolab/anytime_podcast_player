// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/timeline/timeline_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mock [PodcastService] that only overrides the paginated methods.
/// All other methods throw [UnimplementedError] via [Fake].
class FakePodcastService extends Fake implements PodcastService {
  final Future<List<Episode>> Function(DateTime before, int limit)? _loadBefore;
  final Future<int> Function(DateTime since)? _countSince;
  final List<Episode>? Function()? _allEpisodes;

  FakePodcastService({
    Future<List<Episode>> Function(DateTime before, int limit)? loadBefore,
    Future<int> Function(DateTime since)? countSince,
    List<Episode>? Function()? allEpisodes,
  })  : _loadBefore = loadBefore,
        _countSince = countSince,
        _allEpisodes = allEpisodes;

  @override
  Future<List<Episode>> loadEpisodes() async => _allEpisodes?.call() ?? [];

  @override
  Future<List<Episode>> loadEpisodesBefore(DateTime beforeDate, {int limit = 100}) async {
    return _loadBefore?.call(beforeDate, limit) ?? [];
  }

  @override
  Future<int> countEpisodesSince(DateTime sinceDate) async {
    return _countSince?.call(sinceDate) ?? 0;
  }
}

void main() {
  group('TimelineBloc', () {
    test('refresh emits BlocLoadingState then BlocPopulatedState with episodes', () async {
      final episodes = [
        Episode(
          guid: 'ep-1',
          podcast: 'Test Podcast',
          title: 'Episode 1',
          publicationDate: DateTime(2026, 7, 15),
          duration: 1800000,
        ),
        Episode(
          guid: 'ep-2',
          podcast: 'Test Podcast',
          title: 'Episode 2',
          publicationDate: DateTime(2026, 7, 10),
          duration: 1200000,
        ),
      ];

      final service = FakePodcastService(
        loadBefore: (_, __) async => episodes,
        countSince: (_) async => 2,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states[0], isA<BlocLoadingState>());
      expect(states[states.length - 1], isA<BlocPopulatedState<List<Episode>>>());

      final lastState = states.last as BlocPopulatedState<List<Episode>>;
      expect(lastState.results, isNotNull);
      expect(lastState.results!.length, 2);
      // Default sort newest-first → ep-1 (Jul 15) first
      expect(lastState.results![0].guid, 'ep-1');
    });

    test('refresh with empty episodes emits BlocPopulatedState with empty list', () async {
      final service = FakePodcastService(
        loadBefore: (_, __) async => [],
        countSince: (_) async => 0,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is BlocPopulatedState), isTrue);
      final last = states.last as BlocPopulatedState<List<Episode>>;
      expect(last.results, isEmpty);
    });

    test('sortOldestFirst reverses episode order', () async {
      final episodes = [
        Episode(
          guid: 'ep-3',
          podcast: 'Test Podcast',
          title: 'Episode 3',
          publicationDate: DateTime(2026, 7, 20),
          duration: 900000,
        ),
        Episode(
          guid: 'ep-1',
          podcast: 'Test Podcast',
          title: 'Episode 1',
          publicationDate: DateTime(2026, 7, 15),
          duration: 1800000,
        ),
        Episode(
          guid: 'ep-2',
          podcast: 'Test Podcast',
          title: 'Episode 2',
          publicationDate: DateTime(2026, 7, 10),
          duration: 1200000,
        ),
      ];

      final service = FakePodcastService(
        loadBefore: (_, __) async => episodes,
        countSince: (_) async => 3,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      // Load episodes
      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      // Default: newest-first → ep-3, ep-1, ep-2
      var loaded = states.last as BlocPopulatedState<List<Episode>>;
      expect(loaded.results![0].guid, 'ep-3');
      expect(loaded.results![1].guid, 'ep-1');
      expect(loaded.results![2].guid, 'ep-2');

      // Toggle to oldest-first
      bloc.event(TimelineEvent.sortOldestFirst);
      await Future.delayed(const Duration(milliseconds: 100));

      loaded = states.last as BlocPopulatedState<List<Episode>>;
      expect(loaded.results![0].guid, 'ep-2');
      expect(loaded.results![1].guid, 'ep-1');
      expect(loaded.results![2].guid, 'ep-3');
    });

    test('loadMore appends next page and updates cursor', () async {
      int callCount = 0;
      final page1 = [
        Episode(
          guid: 'ep-1',
          podcast: 'Test',
          title: 'Episode 1',
          publicationDate: DateTime(2026, 7, 15),
          duration: 1000,
        ),
        Episode(
          guid: 'ep-2',
          podcast: 'Test',
          title: 'Episode 2',
          publicationDate: DateTime(2026, 7, 10),
          duration: 1000,
        ),
      ];
      final page2 = [
        Episode(
          guid: 'ep-3',
          podcast: 'Test',
          title: 'Episode 3',
          publicationDate: DateTime(2026, 7, 5),
          duration: 1000,
        ),
        Episode(
          guid: 'ep-4',
          podcast: 'Test',
          title: 'Episode 4',
          publicationDate: DateTime(2026, 7, 1),
          duration: 1000,
        ),
      ];

      final service = FakePodcastService(
        loadBefore: (_, __) async {
          callCount++;
          return callCount == 1 ? page1 : page2;
        },
        countSince: (_) async => 4,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      // Load first page (refresh)
      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      var loaded = states.last as BlocPopulatedState<List<Episode>>;
      expect(loaded.results!.length, 2);
      expect(callCount, 1);

      // Load more
      bloc.event(TimelineEvent.loadMore);
      await Future.delayed(const Duration(milliseconds: 100));

      loaded = states.last as BlocPopulatedState<List<Episode>>;
      expect(loaded.results!.length, 4);
      expect(callCount, 2);
    });

    test('hasMore is false after a page smaller than pageSize', () async {
      final page = [
        Episode(
          guid: 'ep-1',
          podcast: 'Test',
          title: 'Episode 1',
          publicationDate: DateTime(2026, 7, 15),
          duration: 1000,
        ),
      ];

      final service = FakePodcastService(
        loadBefore: (_, __) async => page,
        countSince: (_) async => 1,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.hasMore, isFalse);
    });

    test('refresh clears accumulated list and reloads from beginning', () async {
      int callCount = 0;
      final page1 = [
        Episode(
          guid: 'ep-old',
          podcast: 'Test',
          title: 'Old Episode',
          publicationDate: DateTime(2026, 7, 1),
          duration: 1000,
        ),
      ];
      final page2 = [
        Episode(
          guid: 'ep-new',
          podcast: 'Test',
          title: 'New Episode',
          publicationDate: DateTime(2026, 7, 15),
          duration: 1000,
        ),
      ];

      final service = FakePodcastService(
        loadBefore: (_, __) async {
          callCount++;
          return callCount == 1 ? page1 : page2;
        },
        countSince: (_) async => 2,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      // First load
      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));
      expect((states.last as BlocPopulatedState<List<Episode>>).results!.length, 1);
      expect((states.last as BlocPopulatedState<List<Episode>>).results![0].guid, 'ep-old');

      // Refresh again — should clear and fetch fresh page
      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));
      expect((states.last as BlocPopulatedState<List<Episode>>).results!.length, 1);
      expect((states.last as BlocPopulatedState<List<Episode>>).results![0].guid, 'ep-new');
    });

    test('dispose closes all subjects', () async {
      final service = FakePodcastService(
        loadBefore: (_, __) async => [],
        countSince: (_) async => 0,
      );
      final bloc = TimelineBloc(podcastService: service);
      expect(() => bloc.dispose(), returnsNormally);
    });

    test('jumpToDate loads pages and emits populated state', () async {
      final episodes = List.generate(150, (i) {
        return Episode(
          guid: 'ep-$i',
          podcast: 'Test',
          title: 'Episode $i',
          publicationDate: DateTime(2026, 7, 30 - i),
          duration: 1000,
        );
      });

      int pageLoadCount = 0;
      final service = FakePodcastService(
        loadBefore: (_, __) async {
          pageLoadCount++;
          final start = (pageLoadCount - 1) * 100;
          final end = start + 100;
          if (start >= episodes.length) return [];
          return episodes.sublist(start, end > episodes.length ? episodes.length : end);
        },
        countSince: (_) async => 50,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      bloc.jumpToDate(DateTime(2026, 7, 15));
      await Future.delayed(const Duration(milliseconds: 100));

      final lastState = states.last;
      expect(lastState, isA<BlocPopulatedState<List<Episode>>>());
      // After date filtering, only episodes *exactly on* Jul 15 remain.
      // With dates Jul 30 down to Jul 15, only ep‑15 matches.
      expect((lastState as BlocPopulatedState<List<Episode>>).results!.length, 1);
    });

    test('refresh error emits BlocErrorState', () async {
      final service = FakePodcastService(
        loadBefore: (_, __) => throw Exception('DB error'),
        countSince: (_) async => 0,
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.refresh);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is BlocErrorState), isTrue);
    });
  });
}
