// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/podcast/bookmark_view.dart';
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

Widget _wrap({required BookmarkBloc bookmarkBloc, required AudioBloc audioBloc}) {
  return MaterialApp(
    localizationsDelegates: const [AnytimeLocalisationsDelegate()],
    supportedLocales: const [Locale('en')],
    home: MultiProvider(
      providers: [
        Provider<BookmarkBloc>.value(value: bookmarkBloc),
        Provider<AudioBloc>.value(value: audioBloc),
      ],
      child: const Scaffold(body: BookmarkView()),
    ),
  );
}

/// The widgets under test are created inside the test body on purpose: futures
/// created in `setUp` are bound to the outer zone and would not complete while
/// the widget tester pumps frames.
void main() {
  const episodeOne = 'ep-1';
  const episodeTwo = 'ep-2';

  Episode episode(String guid) => Episode(guid: guid, podcast: 'Test Podcast', title: guid);

  Future<void> addBookmark(FakeRepository repository, String episodeGuid, int positionMs) {
    return repository.saveBookmark(Bookmark(
      episodeGuid: episodeGuid,
      episodeTitle: episodeGuid,
      positionMs: positionMs,
      createdAt: DateTime(2026, 7, 1),
    ));
  }

  testWidgets('shows the playing episode bookmarks and refreshes when the episode changes', (tester) async {
    final repository = FakeRepository();
    final bookmarkBloc = BookmarkBloc(repository: repository);
    final audioPlayerService = _FakeAudioPlayerService();
    final audioBloc = AudioBloc(audioPlayerService: audioPlayerService);

    addTearDown(() {
      bookmarkBloc.dispose();
      audioBloc.dispose();
    });

    await addBookmark(repository, episodeOne, 1000);
    await addBookmark(repository, episodeTwo, 2000);

    audioPlayerService.episodeController.add(episode(episodeOne));

    await tester.pumpWidget(_wrap(bookmarkBloc: bookmarkBloc, audioBloc: audioBloc));
    await tester.pumpAndSettle();

    expect(find.text('00:00:01'), findsOneWidget);
    expect(find.text('00:00:02'), findsNothing);

    // Switching episode must drop the previous bookmarks (they belong to a
    // different episode and would seek the wrong position) and load the new
    // episode's bookmarks.
    audioPlayerService.episodeController.add(episode(episodeTwo));
    await tester.pumpAndSettle();

    expect(find.text('00:00:01'), findsNothing);
    expect(find.text('00:00:02'), findsOneWidget);
  });

  testWidgets('all-scope states do not replace the episode bookmarks', (tester) async {
    final repository = FakeRepository();
    final bookmarkBloc = BookmarkBloc(repository: repository);
    final audioPlayerService = _FakeAudioPlayerService();
    final audioBloc = AudioBloc(audioPlayerService: audioPlayerService);

    addTearDown(() {
      bookmarkBloc.dispose();
      audioBloc.dispose();
    });

    await addBookmark(repository, episodeOne, 1000);
    await addBookmark(repository, episodeTwo, 2000);

    audioPlayerService.episodeController.add(episode(episodeOne));

    await tester.pumpWidget(_wrap(bookmarkBloc: bookmarkBloc, audioBloc: audioBloc));
    await tester.pumpAndSettle();

    expect(find.text('00:00:01'), findsOneWidget);

    // The bookmarks overview fetches the all scope on the same BLoC; the Now
    // Playing view must keep showing the current episode's bookmarks.
    bookmarkBloc.event(BookmarkFetchAllEvent());
    await tester.pumpAndSettle();

    expect(find.text('00:00:01'), findsOneWidget);
    expect(find.text('00:00:02'), findsNothing);
  });

  testWidgets('tapping a bookmark seeks the player to its position', (tester) async {
    final repository = FakeRepository();
    final bookmarkBloc = BookmarkBloc(repository: repository);
    final audioPlayerService = _FakeAudioPlayerService();
    final audioBloc = AudioBloc(audioPlayerService: audioPlayerService);

    addTearDown(() {
      bookmarkBloc.dispose();
      audioBloc.dispose();
    });

    await addBookmark(repository, episodeOne, 5000);

    audioPlayerService.episodeController.add(episode(episodeOne));

    await tester.pumpWidget(_wrap(bookmarkBloc: bookmarkBloc, audioBloc: audioBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('00:00:05'));
    await tester.pumpAndSettle();

    expect(audioPlayerService.seeks, contains(5));
  });
}
