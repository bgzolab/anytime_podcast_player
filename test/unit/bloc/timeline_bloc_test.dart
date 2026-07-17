// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/timeline/timeline_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mock [PodcastService] that only overrides [loadEpisodes].
/// All other methods throw [UnimplementedError] via [Fake].
class FakePodcastService extends Fake implements PodcastService {
  final Future<List<Episode>> Function() _loadEpisodesImpl;

  FakePodcastService({required Future<List<Episode>> Function() loadEpisodesImpl})
      : _loadEpisodesImpl = loadEpisodesImpl;

  @override
  Future<List<Episode>> loadEpisodes() => _loadEpisodesImpl();
}

void main() {
  group('TimelineBloc', () {
    test('fetch emits BlocLoadingState then BlocPopulatedState with episodes', () async {
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

      final service = FakePodcastService(loadEpisodesImpl: () async => episodes);
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.fetch);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states[0], isA<BlocLoadingState>());
      expect(states[1], isA<BlocPopulatedState<List<Episode>>>());

      final populatedState = states[1] as BlocPopulatedState<List<Episode>>;
      expect(populatedState.results, isNotNull);
      expect(populatedState.results!.length, 2);
      // Default sort is newest-first so Episode 1 (Jul 15) should be first
      expect(populatedState.results![0].guid, 'ep-1');
      expect(populatedState.results![1].guid, 'ep-2');
    });

    test('fetch with empty episodes emits BlocPopulatedState with empty list', () async {
      final service = FakePodcastService(loadEpisodesImpl: () async => []);
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.fetch);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is BlocPopulatedState), isTrue);
      final populatedState = states.lastWhere((s) => s is BlocPopulatedState) as BlocPopulatedState<List<Episode>>;
      expect(populatedState.results, isEmpty);
    });

    test('sortOldestFirst reverses episode order', () async {
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
        Episode(
          guid: 'ep-3',
          podcast: 'Test Podcast',
          title: 'Episode 3',
          publicationDate: DateTime(2026, 7, 20),
          duration: 900000,
        ),
      ];

      final service = FakePodcastService(loadEpisodesImpl: () async => episodes);
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      // Load episodes first
      bloc.event(TimelineEvent.fetch);
      await Future.delayed(const Duration(milliseconds: 100));

      // Default sort: newest-first → ep-3 (Jul 20), ep-1 (Jul 15), ep-2 (Jul 10)
      var loadedState = states.lastWhere((s) => s is BlocPopulatedState) as BlocPopulatedState<List<Episode>>;
      expect(loadedState.results![0].guid, 'ep-3');
      expect(loadedState.results![1].guid, 'ep-1');
      expect(loadedState.results![2].guid, 'ep-2');

      // Toggle to oldest-first
      bloc.event(TimelineEvent.sortOldestFirst);
      await Future.delayed(const Duration(milliseconds: 100));

      loadedState = states.lastWhere((s) => s is BlocPopulatedState) as BlocPopulatedState<List<Episode>>;
      expect(loadedState.results![0].guid, 'ep-2');
      expect(loadedState.results![1].guid, 'ep-1');
      expect(loadedState.results![2].guid, 'ep-3');
    });

    test('sortNewestFirst re-sorts and stays newest-first', () async {
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

      final service = FakePodcastService(loadEpisodesImpl: () async => episodes);
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      // Load episodes
      bloc.event(TimelineEvent.fetch);
      await Future.delayed(const Duration(milliseconds: 100));

      // Toggle to oldest-first
      bloc.event(TimelineEvent.sortOldestFirst);
      await Future.delayed(const Duration(milliseconds: 100));

      var loadedState = states.lastWhere((s) => s is BlocPopulatedState) as BlocPopulatedState<List<Episode>>;
      expect(loadedState.results![0].guid, 'ep-2');

      // Toggle back to newest-first
      bloc.event(TimelineEvent.sortNewestFirst);
      await Future.delayed(const Duration(milliseconds: 100));

      loadedState = states.lastWhere((s) => s is BlocPopulatedState) as BlocPopulatedState<List<Episode>>;
      expect(loadedState.results![0].guid, 'ep-1');
      expect(loadedState.results![1].guid, 'ep-2');
    });

    test('dispose closes event subject', () async {
      final service = FakePodcastService(loadEpisodesImpl: () async => []);
      final bloc = TimelineBloc(podcastService: service);

      expect(() => bloc.dispose(), returnsNormally);
    });

    test('sort toggle before fetch does nothing (no cached data)', () async {
      final service = FakePodcastService(loadEpisodesImpl: () async => []);
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.sortOldestFirst);
      await Future.delayed(const Duration(milliseconds: 100));

      // No state should be emitted since cache is empty
      expect(states, isEmpty);
    });

    test('fetch error emits BlocErrorState', () async {
      final service = FakePodcastService(
        loadEpisodesImpl: () => throw Exception('Network error'),
      );
      final bloc = TimelineBloc(podcastService: service);
      addTearDown(() => bloc.dispose());

      final states = <BlocState>[];
      bloc.state?.listen((state) {
        states.add(state);
      });

      bloc.event(TimelineEvent.fetch);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is BlocErrorState), isTrue);
    });
  });
}
