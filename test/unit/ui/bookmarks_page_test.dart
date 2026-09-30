// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/library/bookmarks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../mocks/fake_repository.dart';

Widget _wrap(BookmarkBloc bloc) {
  return MaterialApp(
    localizationsDelegates: const [AnytimeLocalisationsDelegate()],
    supportedLocales: const [Locale('en')],
    home: MultiProvider(
      providers: [Provider<BookmarkBloc>.value(value: bloc)],
      child: const Scaffold(
        body: CustomScrollView(
          slivers: [BookmarksPage()],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // Same initialisation the app performs in main(); the bookmark tiles format
    // their creation date for the current locale.
    await initializeDateFormatting();
  });

  Future<void> addBookmark(
    FakeRepository repository, {
    required String episodeGuid,
    required String episodeTitle,
    required String podcastName,
    required String podcastGuid,
    required int positionMs,
    required DateTime createdAt,
  }) {
    return repository.saveBookmark(Bookmark(
      episodeGuid: episodeGuid,
      episodeTitle: episodeTitle,
      podcastName: podcastName,
      podcastGuid: podcastGuid,
      positionMs: positionMs,
      createdAt: createdAt,
    ));
  }

  testWidgets('groups bookmarks by podcast and episode, ordered by position', (tester) async {
    final repository = FakeRepository();
    final bloc = BookmarkBloc(repository: repository);
    addTearDown(() => bloc.dispose());

    await addBookmark(
      repository,
      episodeGuid: 'ep-1',
      episodeTitle: 'Episode One',
      podcastName: 'Podcast A',
      podcastGuid: 'p-a',
      positionMs: 20000,
      createdAt: DateTime(2026, 7, 1),
    );
    await addBookmark(
      repository,
      episodeGuid: 'ep-1',
      episodeTitle: 'Episode One',
      podcastName: 'Podcast A',
      podcastGuid: 'p-a',
      positionMs: 10000,
      createdAt: DateTime(2026, 7, 2),
    );
    await addBookmark(
      repository,
      episodeGuid: 'ep-2',
      episodeTitle: 'Episode Two',
      podcastName: 'Podcast B',
      podcastGuid: 'p-b',
      positionMs: 30000,
      createdAt: DateTime(2026, 7, 3),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Podcast A'), findsOneWidget);
    expect(find.text('Podcast B'), findsOneWidget);
    expect(find.text('Episode One'), findsOneWidget);
    expect(find.text('Episode Two'), findsOneWidget);

    // Plural-aware, localised header counts.
    expect(find.text('1 episode · 2 bookmarks'), findsOneWidget);
    expect(find.text('1 episode · 1 bookmark'), findsOneWidget);

    // Within an episode, bookmarks are ordered by position (matching the Now
    // Playing view) rather than by creation time.
    final positions = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data == '00:00:10' || data == '00:00:20')
        .toList();
    expect(positions, ['00:00:10', '00:00:20']);
  });

  testWidgets('ignores episode-scoped states from the shared bloc', (tester) async {
    final repository = FakeRepository();
    final bloc = BookmarkBloc(repository: repository);
    addTearDown(() => bloc.dispose());

    await addBookmark(
      repository,
      episodeGuid: 'ep-1',
      episodeTitle: 'Episode One',
      podcastName: 'Podcast A',
      podcastGuid: 'p-a',
      positionMs: 10000,
      createdAt: DateTime(2026, 7, 1),
    );
    await addBookmark(
      repository,
      episodeGuid: 'ep-2',
      episodeTitle: 'Episode Two',
      podcastName: 'Podcast B',
      podcastGuid: 'p-b',
      positionMs: 20000,
      createdAt: DateTime(2026, 7, 2),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Podcast A'), findsOneWidget);
    expect(find.text('Podcast B'), findsOneWidget);

    // The Now Playing view fetches its episode scope on the same BLoC; the
    // overview must keep showing all bookmarks.
    bloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: 'ep-2'));
    await tester.pumpAndSettle();

    expect(find.text('Podcast A'), findsOneWidget);
    expect(find.text('Podcast B'), findsOneWidget);
  });

  testWidgets('dismissing a bookmark removes it from the list', (tester) async {
    final repository = FakeRepository();
    final bloc = BookmarkBloc(repository: repository);
    addTearDown(() => bloc.dispose());

    await addBookmark(
      repository,
      episodeGuid: 'ep-1',
      episodeTitle: 'Episode One',
      podcastName: 'Podcast A',
      podcastGuid: 'p-a',
      positionMs: 10000,
      createdAt: DateTime(2026, 7, 1),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('00:00:10'), findsOneWidget);

    await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('No bookmarks yet'), findsOneWidget);
  });
}
