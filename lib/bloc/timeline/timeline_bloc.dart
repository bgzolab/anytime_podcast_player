// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// Events that can be sent to the [TimelineBloc].
enum TimelineEvent {
  /// Clear all episodes and reload from the newest (page 1).
  refresh,

  /// Load the next page of older episodes (cursor-based pagination).
  loadMore,

  /// Toggle whether played episodes are shown or hidden.
  toggleShowPlayed,

  /// Load enough pages to cover the date most recently passed to
  /// [TimelineBloc.jumpToDate] and apply it as a filter.
  jumpToDate,
}

/// The BLoC provides cursor-paginated access to all episodes from subscribed
/// podcasts, grouped by date, always sorted newest-first.
///
/// ## Pagination
///
/// - **Initial load**: the widget (or [resume]) sends a [TimelineEvent.refresh]
///   to load the first page (newest [pageSize] episodes).
/// - **Infinite scroll**: the widget sends [TimelineEvent.loadMore] when the
///   user scrolls near the bottom. The BLoC loads the next [pageSize] episodes
///   older than the cursor (`_cursor`, the oldest [publicationDate] seen so
///   far). The cursor query is inclusive so episodes sharing a publication
///   date are not skipped; duplicates are filtered by guid.
/// - **Date jump**: calling [jumpToDate] queries the offset of the given date
///   and loads all pages up to that point, then emits the accumulated list.
///
/// All events (including date jumps) are processed by a single pipeline so
/// that operations cannot interleave and corrupt the shared page state.
///
/// Output uses [BehaviorSubject] so subscribers always receive the last emitted
/// state, even when subscribing late (e.g. after a tab switch).
class TimelineBloc extends Bloc {
  final log = Logger('TimelineBloc');
  final PodcastService podcastService;

  final PublishSubject<TimelineEvent> _eventInput = PublishSubject<TimelineEvent>();
  final BehaviorSubject<BlocState<List<Episode>>> _stateOutput = BehaviorSubject<BlocState<List<Episode>>>();

  bool _isLoadingMore = false;
  bool _showPlayed = false;

  /// Accumulated episodes across all loaded pages.
  final List<Episode> _allEpisodes = [];

  /// The oldest [publicationDate] among loaded episodes. Used as cursor for
  /// the next `loadMore` call. `null` after [refresh] before first page loads.
  DateTime? _cursor;

  /// Whether the server-side has more episodes beyond the current pages.
  bool _hasMore = true;

  /// When set (via [jumpToDate]), only episodes on or after this date are shown.
  DateTime? _dateFilter;

  /// The date most recently passed to [jumpToDate], consumed by
  /// [TimelineEvent.jumpToDate] on the shared event pipeline.
  DateTime? _pendingJumpDate;

  /// Completes when the next non-loading state is emitted; used by
  /// [refreshAndWait] so the UI can keep its refresh indicator running.
  Completer<void>? _refreshCompleter;

  DateTime? _lastFetchTime;

  static const int pageSize = 20;
  static const Duration maxStale = Duration(minutes: 5);

  TimelineBloc({
    required this.podcastService,
  }) {
    _init();
  }

  @override
  void resume() async {
    log.fine('Resuming from Timeline BLoC');
    if (_lastFetchTime == null || DateTime.now().difference(_lastFetchTime!) > maxStale) {
      log.fine('Cached data is stale — re-fetching from page 1');
      _eventInput.add(TimelineEvent.refresh);
    } else {
      log.fine('Cached data is fresh — skipping re-fetch');
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Add a [TimelineEvent] to the input sink.
  void Function(TimelineEvent) get event => _eventInput.add;

  /// Stream of [BlocState] changes. Uses [BehaviorSubject] so late subscribers
  /// always get the last emitted state (no blank screen).
  Stream<BlocState<List<Episode>>> get state => _stateOutput.stream;

  /// Whether played episodes are currently shown (true) or hidden (false).
  bool get showPlayed => _showPlayed;

  /// Whether there are played episodes that are being hidden by the filter.
  bool get hasHiddenPlayed => !_showPlayed && _allEpisodes.any((ep) => ep.played);

  /// Whether at least one successful fetch has completed.
  bool get hasData => _lastFetchTime != null;

  /// Whether more pages are available beyond the current loaded set.
  /// Returns `false` when a date filter is active (all episodes for a
  /// single day are loaded in one go; infinite scroll makes no sense).
  bool get hasMore => _dateFilter == null && _hasMore;

  /// If set, only episodes on or after this date are shown in the list.
  /// Set by [jumpToDate], cleared by [refresh] or [clearDateFilter].
  DateTime? get dateFilter => _dateFilter;

  /// Force a fresh fetch from the database (page 1) and clear any date filter.
  void refresh() => _eventInput.add(TimelineEvent.refresh);

  /// Refresh page 1 and complete once a populated (or error) state has been
  /// emitted.
  ///
  /// [state] is a [BehaviorSubject] and replays the previous value on
  /// subscription, so UI code cannot rely on `state.firstWhere(...)` to know
  /// when a refresh has finished. This Future completes only when the refresh
  /// triggered here actually produces a result.
  Future<void> refreshAndWait() {
    _refreshCompleter?.complete();
    final completer = _refreshCompleter = Completer<void>();

    _eventInput.add(TimelineEvent.refresh);

    return completer.future;
  }

  /// Clear the active date filter and show all loaded episodes.
  void clearDateFilter() {
    _dateFilter = null;
    _eventInput.add(TimelineEvent.refresh);
  }

  /// Load the next page if available (no-op if already at the end or loading).
  void loadMore() {
    if (!_isLoadingMore && _hasMore) {
      _eventInput.add(TimelineEvent.loadMore);
    }
  }

  /// Jump to the timeline position for [date]. Loads pages until the target is
  /// reached, then emits so the UI can scroll to the appropriate item.
  void jumpToDate(DateTime date) {
    _pendingJumpDate = date;
    _eventInput.add(TimelineEvent.jumpToDate);
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  void _init() {
    // All events share one pipeline so refresh/loadMore/jumpToDate cannot
    // interleave and corrupt the shared page state.
    _eventInput.switchMap<BlocState<List<Episode>>>((TimelineEvent event) {
      switch (event) {
        case TimelineEvent.refresh:
          return _refresh();
        case TimelineEvent.loadMore:
          return _loadMore();
        case TimelineEvent.toggleShowPlayed:
          _showPlayed = !_showPlayed;
          return _emitFromCache();
        case TimelineEvent.jumpToDate:
          return _jumpToDate(_pendingJumpDate!);
      }
    }).listen((state) {
      _stateOutput.add(state);
      _completeRefreshWait(state);
    });
  }

  /// Completes a pending [refreshAndWait] Future once a real result is emitted.
  void _completeRefreshWait(BlocState<List<Episode>> state) {
    final completer = _refreshCompleter;

    if (completer == null || completer.isCompleted) return;
    if (state is BlocPopulatedState<List<Episode>> || state is BlocErrorState<List<Episode>>) {
      _refreshCompleter = null;
      completer.complete();
    }
  }

  // ---------------------------------------------------------------------------
  // Page load helpers
  // ---------------------------------------------------------------------------

  /// Clears state (including any date filter) and loads the first page.
  /// The previous list is kept in the loading state so the UI can show it
  /// underneath the refresh indicator instead of a blank spinner.
  Stream<BlocState<List<Episode>>> _refresh() async* {
    final previous = List<Episode>.from(_allEpisodes);

    _allEpisodes.clear();
    _dateFilter = null;
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;

    yield BlocLoadingState<List<Episode>>(_sorted(previous));

    try {
      await _fetchPage();
      _lastFetchTime = DateTime.now();
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
    } catch (e) {
      log.severe('Timeline refresh failed: $e');
      yield BlocErrorState<List<Episode>>();
    }
  }

  /// Appends the next page (older episodes). Shows a background-loading
  /// indicator while fetching so the UI stays responsive.
  Stream<BlocState<List<Episode>>> _loadMore() async* {
    if (_cursor == null || _allEpisodes.isEmpty) return;

    _isLoadingMore = true;

    // Keep the current list visible while loading in the background.
    yield BlocBackgroundLoadingState<List<Episode>>(_sorted(_allEpisodes));

    try {
      await _fetchPage();
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
    } catch (e) {
      log.severe('Timeline loadMore failed: $e');
      // Re-emit current data so the UI isn't stuck in a loading state.
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Shared helper: fetches one page and appends to [_allEpisodes].
  /// Uses [_cursor] as the (inclusive) "before" bound, and updates it
  /// afterwards. Episodes already loaded are skipped so that an inclusive
  /// cursor cannot produce duplicates.
  Future<void> _fetchPage() async {
    final before = _cursor ?? DateTime.now().add(const Duration(days: 1));
    final page = await podcastService.loadEpisodesBefore(before, limit: pageSize);

    if (page.isEmpty) {
      _hasMore = false;
      return;
    }

    final known = _allEpisodes.map((episode) => episode.guid).toSet();
    final fresh = page.where((episode) => !known.contains(episode.guid)).toList();

    _allEpisodes.addAll(fresh);

    // Update cursor to the oldest episode in this page.
    // loadEpisodesBefore returns newest-first, so last is the oldest.
    _cursor = page.last.publicationDate;

    // If we got fewer than pageSize, there are no more pages. If everything
    // was already known (a full page sharing the cursor timestamp), stop too —
    // otherwise the same page would be fetched forever.
    if (page.length < pageSize || fresh.isEmpty) {
      _hasMore = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Date jump
  // ---------------------------------------------------------------------------

  /// Sets a date filter and loads enough pages to cover [date], then emits
  /// the filtered list so the UI shows episodes only from [date] onwards.
  Stream<BlocState<List<Episode>>> _jumpToDate(DateTime date) async* {
    _dateFilter = date;
    yield BlocLoadingState<List<Episode>>(_sorted(_allEpisodes));

    try {
      // Count how many episodes are newer than [date] to know how many pages
      // are needed, then load pages until we reach or exceed that count.
      final offset = await podcastService.countEpisodesSince(date);

      // Load pages one at a time until we have enough (or run out).
      while (_allEpisodes.length < offset + pageSize && _hasMore) {
        await _fetchPage();
      }

      _lastFetchTime = DateTime.now();
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
    } catch (e) {
      log.severe('Timeline jumpToDate failed: $e');
      // If we have data, emit it anyway.
      if (_allEpisodes.isNotEmpty) {
        yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
      } else {
        yield BlocErrorState<List<Episode>>();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sorting & cache helpers
  // ---------------------------------------------------------------------------

  /// Re-emits the current [_allEpisodes] with the active sort direction.
  Stream<BlocState<List<Episode>>> _emitFromCache() async* {
    if (_allEpisodes.isNotEmpty) {
      yield BlocPopulatedState<List<Episode>>(results: _sorted(_allEpisodes));
    } else {
      yield BlocDefaultState<List<Episode>>();
    }
  }

  /// Returns a new sorted list from [episodes] according to [_sortDescending].
  /// If [_dateFilter] is set, only episodes from **that calendar day**
  /// (year/month/day) are included.
  List<Episode> _sorted(List<Episode> episodes) {
    var filtered = episodes;

    if (_dateFilter != null) {
      final filterDay = DateTime(_dateFilter!.year, _dateFilter!.month, _dateFilter!.day);
      filtered = episodes.where((ep) {
        final d = ep.publicationDate;
        if (d == null) return false;
        final epDay = DateTime(d.year, d.month, d.day);
        return epDay == filterDay;
      }).toList();
    }

    // Hide played episodes unless the user has opted to show them.
    if (!_showPlayed) {
      filtered = filtered.where((ep) => !ep.played).toList();
    }

    if (filtered.isEmpty) return filtered;

    final sorted = List<Episode>.from(filtered);
    sorted.sort((a, b) {
      final da = a.publicationDate ?? DateTime.now();
      final db = b.publicationDate ?? DateTime.now();
      return db.compareTo(da); // Always newest-first
    });
    return sorted;
  }

  @override
  void dispose() {
    _refreshCompleter?.complete();
    _refreshCompleter = null;
    _eventInput.close();
    _stateOutput.close();
    super.dispose();
  }
}
