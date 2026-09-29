// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// Events that can be sent to the [BookmarkBloc].
abstract class BookmarkEvent {}

/// Fetch all bookmarks across all episodes.
class BookmarkFetchAllEvent extends BookmarkEvent {}

/// Fetch bookmarks for a specific episode.
class BookmarkFetchByEpisodeEvent extends BookmarkEvent {
  final String episodeGuid;

  BookmarkFetchByEpisodeEvent({required this.episodeGuid});
}

/// Create a new bookmark at the given position.
class BookmarkCreateEvent extends BookmarkEvent {
  final Episode episode;
  final int positionMs;
  final String? note;

  BookmarkCreateEvent({
    required this.episode,
    required this.positionMs,
    this.note,
  });
}

/// Delete an existing bookmark.
class BookmarkDeleteEvent extends BookmarkEvent {
  final Bookmark bookmark;

  BookmarkDeleteEvent({required this.bookmark});
}

/// BLoC to manage bookmark state — creating, fetching, and deleting bookmarks.
class BookmarkBloc extends Bloc {
  final log = Logger('BookmarkBloc');
  final Repository repository;

  final PublishSubject<BookmarkEvent> _eventInput = PublishSubject<BookmarkEvent>();
  final BehaviorSubject<BlocState<List<Bookmark>>> _stateOutput = BehaviorSubject<BlocState<List<Bookmark>>>();

  /// The episode GUID of the currently active fetch-by-episode request, or
  /// `null` when the last request was a fetch-all. Used to re-fetch the same
  /// scope after create/delete operations.
  String? _currentEpisodeGuid;

  BookmarkBloc({
    required this.repository,
  }) {
    _init();
  }

  /// Add a [BookmarkEvent] to the input sink.
  void Function(BookmarkEvent) get event => _eventInput.add;

  /// Stream of [BlocState] changes.
  Stream<BlocState<List<Bookmark>>> get state => _stateOutput.stream;

  void _init() {
    _eventInput.switchMap<BlocState<List<Bookmark>>>((BookmarkEvent event) {
      if (event is BookmarkFetchAllEvent) {
        // Reset the scope so create/delete refresh the full list again.
        _currentEpisodeGuid = null;

        return _fetchAll();
      } else if (event is BookmarkFetchByEpisodeEvent) {
        _currentEpisodeGuid = event.episodeGuid;
        return _fetchByEpisode(event.episodeGuid);
      } else if (event is BookmarkCreateEvent) {
        return _create(event);
      } else if (event is BookmarkDeleteEvent) {
        return _delete(event);
      }
      return Stream.value(BlocDefaultState<List<Bookmark>>());
    }).listen((state) => _stateOutput.add(state));
  }

  Stream<BlocState<List<Bookmark>>> _fetchAll() async* {
    try {
      final bookmarks = await repository.findAllBookmarks();
      yield BlocPopulatedState<List<Bookmark>>(results: bookmarks);
    } catch (e) {
      log.severe('Failed to fetch all bookmarks: $e');
      yield BlocErrorState<List<Bookmark>>();
    }
  }

  Stream<BlocState<List<Bookmark>>> _fetchByEpisode(String episodeGuid) async* {
    try {
      final bookmarks = await repository.findBookmarksByEpisodeGuid(episodeGuid);
      yield BlocPopulatedState<List<Bookmark>>(results: bookmarks);
    } catch (e) {
      log.severe('Failed to fetch bookmarks for episode $episodeGuid: $e');
      yield BlocErrorState<List<Bookmark>>();
    }
  }

  Stream<BlocState<List<Bookmark>>> _create(BookmarkCreateEvent event) async* {
    try {
      final bookmark = Bookmark(
        episodeGuid: event.episode.guid,
        episodeTitle: event.episode.title,
        podcastName: event.episode.podcast,
        podcastGuid: event.episode.pguid,
        positionMs: event.positionMs,
        note: event.note,
        createdAt: DateTime.now(),
      );

      await repository.saveBookmark(bookmark);

      // Re-fetch the same scope that the UI is currently showing so the list
      // the user sees is updated (all bookmarks, or one episode's).
      final bookmarks = await _refetch();

      yield BlocPopulatedState<List<Bookmark>>(results: bookmarks);
    } catch (e) {
      log.severe('Failed to create bookmark: $e');
      yield BlocErrorState<List<Bookmark>>();
    }
  }

  Stream<BlocState<List<Bookmark>>> _delete(BookmarkDeleteEvent event) async* {
    try {
      await repository.deleteBookmark(event.bookmark);

      // Re-fetch the same scope that the UI is currently showing so a deleted
      // row cannot remain in the list (which would break Dismissible).
      final bookmarks = await _refetch();

      yield BlocPopulatedState<List<Bookmark>>(results: bookmarks);
    } catch (e) {
      log.severe('Failed to delete bookmark: $e');
      yield BlocErrorState<List<Bookmark>>();
    }
  }

  /// Loads bookmarks using the most recent query scope: all bookmarks when the
  /// last request was a fetch-all, otherwise the bookmarks of that episode.
  Future<List<Bookmark>> _refetch() {
    final episodeGuid = _currentEpisodeGuid;

    if (episodeGuid == null) return repository.findAllBookmarks();

    return repository.findBookmarksByEpisodeGuid(episodeGuid);
  }

  @override
  void dispose() {
    _eventInput.close();
    _stateOutput.close();
    super.dispose();
  }
}
