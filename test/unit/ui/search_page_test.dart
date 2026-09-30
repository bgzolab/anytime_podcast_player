// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/search/search.dart';
import 'package:anytime/ui/search/search_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../mocks/fake_repository.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final episodeController = BehaviorSubject<Episode?>.seeded(null);
  final seeks = <int>[];

  @override
  ValueStream<Episode?>? get episodeEvent => episodeController;

  @override
  Future<void> seek({required int position}) async {
    seeks.add(position);
  }
}

/// A fake whose bookmark search completes only when the test lets it, for
/// exercising in-flight searches.
class _GatedFakeRepository extends FakeRepository {
  final gate = Completer<List<Bookmark>>();

  @override
  Future<List<Bookmark>> searchBookmarks(String term) => gate.future;
}

Widget _wrap(Search search, {AudioBloc? audioBloc, Repository? repository}) {
  return MaterialApp(
    localizationsDelegates: const [AnytimeLocalisationsDelegate()],
    supportedLocales: const [Locale('en')],
    home: MultiProvider(
      providers: [
        if (audioBloc != null) Provider<AudioBloc>.value(value: audioBloc),
        if (repository != null) Provider<Repository>.value(value: repository),
      ],
      child: search,
    ),
  );
}

/// Submits [term] through the search field's callback.
///
/// Driving the callback directly avoids the keyboard plumbing while still
/// covering the widget's own trim/search logic.
/// Pumps the search page and waits for the (asynchronously loaded)
/// localisations to build the widget tree.
Future<void> _pumpSearch(WidgetTester tester, Search search, {AudioBloc? audioBloc, Repository? repository}) async {
  await tester.pumpWidget(_wrap(search, audioBloc: audioBloc, repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String term) async {
  tester.widget<TextField>(find.byType(TextField)).onSubmitted!(term);
  await tester.pumpAndSettle();
}

void main() {
  Future<Bookmark> addBookmark(
    FakeRepository repository, {
    String episodeGuid = 'ep-1',
    String episodeTitle = 'Deep Dive',
    String? podcastName = 'Podcast A',
    int positionMs = 90000,
    String? note = 'hello note',
  }) {
    return repository.saveBookmark(Bookmark(
      episodeGuid: episodeGuid,
      episodeTitle: episodeTitle,
      podcastName: podcastName,
      positionMs: positionMs,
      note: note,
      createdAt: DateTime(2026, 7, 1),
    ));
  }

  testWidgets('trims the search term and renders bookmark results', (tester) async {
    final repository = FakeRepository();

    await addBookmark(repository);

    // No repository on the widget: the local search falls back to the provided
    // Repository.
    await _pumpSearch(tester, const Search(mode: SearchMode.my), repository: repository);
    await _submit(tester, ' hello ');

    expect(repository.lastSearchTerm, 'hello');
    expect(find.text('Deep Dive'), findsOneWidget);
    expect(find.textContaining('01:30'), findsOneWidget);
  });

  testWidgets('shows the bookmark empty state when nothing matches', (tester) async {
    final repository = FakeRepository();

    await addBookmark(repository);

    await _pumpSearch(tester, const Search(mode: SearchMode.my), repository: repository);
    await _submit(tester, 'nothing');

    expect(find.text('No bookmarks found'), findsOneWidget);
  });

  testWidgets('shows the error state when a local search fails', (tester) async {
    final repository = FakeRepository()..failSearches = true;

    await _pumpSearch(tester, const Search(mode: SearchMode.my), repository: repository);
    await _submit(tester, 'hello');

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
    expect(find.text('No bookmarks found'), findsNothing);
    // The error state offers the retry action the message promises.
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('clearing invalidates an in-flight local search', (tester) async {
    final repository = _GatedFakeRepository();

    await _pumpSearch(tester, const Search(mode: SearchMode.my), repository: repository);

    tester.widget<TextField>(find.byType(TextField)).onSubmitted!('hello');
    await tester.pump();

    // Clear while the search is still running.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    // Fail the stale search after the clear: without the generation bump its
    // error would surface as the (visible) error state. The cleared screen
    // must stay clear and show no spinner.
    repository.gate.completeError(Exception('search failed'));
    await tester.pumpAndSettle();

    expect(find.text('Search failed. Please try again.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping a bookmark result seeks the playing episode', (tester) async {
    final repository = FakeRepository();
    final audioPlayerService = _FakeAudioPlayerService();
    final audioBloc = AudioBloc(audioPlayerService: audioPlayerService);

    addTearDown(audioBloc.dispose);

    audioPlayerService.episodeController.add(Episode(guid: 'ep-1', podcast: 'Test', title: 'Episode One'));
    await addBookmark(repository, positionMs: 5000);

    await _pumpSearch(
      tester,
      const Search(mode: SearchMode.my),
      audioBloc: audioBloc,
      repository: repository,
    );
    await _submit(tester, 'note');

    await tester.tap(find.text('Deep Dive'));
    await tester.pumpAndSettle();

    expect(audioPlayerService.seeks, contains(5));
  });

  testWidgets('home mode shows the episode empty state for a non-matching term', (tester) async {
    final repository = FakeRepository();
    repository.searchableEpisodes.add(Episode(guid: 'ep-1', podcast: 'Test', title: 'Deep Dive'));

    await _pumpSearch(tester, const Search(mode: SearchMode.home), repository: repository);
    await _submit(tester, 'nothing');

    expect(find.text('No episodes found'), findsOneWidget);
  });

  testWidgets('home mode shows the error state when the search fails', (tester) async {
    final repository = FakeRepository()..failSearches = true;

    await _pumpSearch(tester, const Search(mode: SearchMode.home), repository: repository);
    await _submit(tester, 'hello');

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('downloads mode shows its own empty state', (tester) async {
    final repository = FakeRepository();

    await _pumpSearch(tester, const Search(mode: SearchMode.download), repository: repository);
    await _submit(tester, 'hello');

    expect(find.text('No downloads found'), findsOneWidget);
  });
}
