// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// Events that can be sent to the [TimelineBloc].
enum TimelineEvent {
  /// Fetch all episodes from subscribed podcasts.
  fetch,

  /// Sort episodes with newest first (descending by publicationDate).
  sortNewestFirst,

  /// Sort episodes with oldest first (ascending by publicationDate).
  sortOldestFirst,
}

/// The BLoC provides access to all episodes from subscribed podcasts,
/// ordered by publication date, with toggle between newest-first and oldest-first.
///
/// This follows the same custom BLoC pattern as [EpisodeBloc] and other
/// BLoCs in this application: events are added to a [PublishSubject] input
/// and transformed via [switchMap] into a [BlocState] output stream.
class TimelineBloc extends Bloc {
  final log = Logger('TimelineBloc');
  final PodcastService podcastService;

  final PublishSubject<TimelineEvent> _eventInput = PublishSubject<TimelineEvent>();
  Stream<BlocState<List<Episode>>>? _stateOutput;

  /// When true, episodes are sorted newest-first (descending).
  /// When false, oldest-first (ascending).
  bool _sortDescending = true;

  /// Cache of the last loaded episode list, so sort toggles don't re-fetch.
  List<Episode>? _cachedEpisodes;

  TimelineBloc({
    required this.podcastService,
  }) {
    _init();
  }

  void _init() {
    _stateOutput = _eventInput.switchMap<BlocState<List<Episode>>>((TimelineEvent event) {
      switch (event) {
        case TimelineEvent.fetch:
          return _load();
        case TimelineEvent.sortNewestFirst:
          _sortDescending = true;
          return _emitFromCache();
        case TimelineEvent.sortOldestFirst:
          _sortDescending = false;
          return _emitFromCache();
      }
    });
  }

  /// Fetches all episodes from [PodcastService] and emits them sorted.
  Stream<BlocState<List<Episode>>> _load() async* {
    yield BlocLoadingState<List<Episode>>();

    try {
      _cachedEpisodes = await podcastService.loadEpisodes();

      yield BlocPopulatedState<List<Episode>>(results: _sorted(_cachedEpisodes!));
    } catch (e) {
      log.severe('Failed to load timeline episodes: $e');
      yield BlocErrorState<List<Episode>>();
    }
  }

  /// Re-emits the cached episode list with the current sort direction.
  Stream<BlocState<List<Episode>>> _emitFromCache() async* {
    if (_cachedEpisodes != null) {
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_cachedEpisodes!));
    }
  }

  /// Whether the current sort is newest-first (descending) or oldest-first (ascending).
  bool get sortDescending => _sortDescending;

  @override
  void resume() async {
    log.fine('Resuming from Timeline BLoC — re-fetching episodes');
    _eventInput.add(TimelineEvent.fetch);
  }

  /// Returns a new sorted list from [episodes] according to [_sortDescending].
  List<Episode> _sorted(List<Episode> episodes) {
    final sorted = List<Episode>.from(episodes);

    sorted.sort((a, b) {
      final da = a.publicationDate ?? DateTime.now();
      final db = b.publicationDate ?? DateTime.now();
      return _sortDescending ? db.compareTo(da) : da.compareTo(db);
    });

    return sorted;
  }

  /// Add an event to the input sink.
  void Function(TimelineEvent) get event => _eventInput.add;

  /// Stream of [BlocState] changes.
  Stream<BlocState<List<Episode>>>? get state => _stateOutput;

  @override
  void dispose() {
    _eventInput.close();
    super.dispose();
  }
}
