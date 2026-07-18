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
  /// Clear all episodes and reload from the newest (page 1).
  refresh,

  /// Load the next page of older episodes (cursor-based pagination).
  loadMore,

  /// Sort episodes with newest first (descending by publicationDate).
  sortNewestFirst,

  /// Sort episodes with oldest first (ascending by publicationDate).
  sortOldestFirst,

  /// Toggle whether played episodes are shown or hidden.
  toggleShowPlayed,
}

/// The BLoC provides cursor-paginated access to all episodes from subscribed
/// podcasts, grouped by date, with a toggle between newest-first and oldest-first.
///
/// ## Pagination
///
/// - **Initial load**: the widget (or [resume]) sends a [TimelineEvent.refresh]
///   to load the first page (newest 100 episodes).
/// - **Infinite scroll**: the widget sends [TimelineEvent.loadMore] when the
///   user scrolls near the bottom. The BLoC loads the next 100 episodes older
///   than the cursor (`_cursor`, the oldest [publicationDate] seen so far).
/// - **Date jump**: calling [jumpToDate] queries the offset of the given date
///   and loads all pages up to that point, then emits the accumulated list.
/// - **Sort toggle**: sort is applied in-memory on the already-loaded list.
///
/// Output uses [BehaviorSubject] so subscribers always receive the last emitted
/// state, even when subscribing late (e.g. after a tab switch).
class TimelineBloc extends Bloc {
  final log = Logger('TimelineBloc');
  final PodcastService podcastService;

  final PublishSubject<TimelineEvent> _eventInput = PublishSubject<TimelineEvent>();
  final PublishSubject<DateTime> _dateJumpInput = PublishSubject<DateTime>();
  final BehaviorSubject<BlocState<List<Episode>>> _stateOutput = BehaviorSubject<BlocState<List<Episode>>>();

  bool _sortDescending = true;
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

  DateTime? _lastFetchTime;

  static const int pageSize = 100;
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

  /// Whether the current sort is newest-first (true) or oldest-first (false).
  bool get sortDescending => _sortDescending;

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
  void jumpToDate(DateTime date) => _dateJumpInput.add(date);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  void _init() {
    // Regular events (refresh / loadMore / sort)
    _eventInput.switchMap<BlocState<List<Episode>>>((TimelineEvent event) {
      switch (event) {
        case TimelineEvent.refresh:
          return _refresh();
        case TimelineEvent.loadMore:
          return _loadMore();
        case TimelineEvent.sortNewestFirst:
          _sortDescending = true;
          return _emitFromCache();
        case TimelineEvent.sortOldestFirst:
          _sortDescending = false;
          return _emitFromCache();
        case TimelineEvent.toggleShowPlayed:
          _showPlayed = !_showPlayed;
          return _emitFromCache();
      }
    }).listen((state) => _stateOutput.add(state));

    // Date-jump events
    _dateJumpInput.switchMap<BlocState<List<Episode>>>((DateTime date) {
      return _jumpToDate(date);
    }).listen((state) => _stateOutput.add(state));
  }

  // ---------------------------------------------------------------------------
  // Page load helpers
  // ---------------------------------------------------------------------------

  /// Clears state (including any date filter) and loads the first page.
  Stream<BlocState<List<Episode>>> _refresh() async* {
    _allEpisodes.clear();
    _dateFilter = null;
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;

    yield BlocLoadingState<List<Episode>>();

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
  /// Uses [_cursor] as the "before" bound, and updates it afterwards.
  Future<void> _fetchPage() async {
    final before = _cursor ?? DateTime.now().add(const Duration(days: 1));
    final page = await podcastService.loadEpisodesBefore(before, limit: pageSize);

    if (page.isEmpty) {
      _hasMore = false;
      return;
    }

    _allEpisodes.addAll(page);

    // Update cursor to the oldest episode in this page.
    // loadEpisodesBefore returns newest-first, so last is the oldest.
    _cursor = page.last.publicationDate;

    // If we got fewer than pageSize, there are no more pages.
    if (page.length < pageSize) {
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
      return _sortDescending ? db.compareTo(da) : da.compareTo(db);
    });
    return sorted;
  }

  @override
  void dispose() {
    _eventInput.close();
    _dateJumpInput.close();
    _stateOutput.close();
    super.dispose();
  }
}
