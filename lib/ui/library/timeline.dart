// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/timeline/timeline_bloc.dart';
import 'package:anytime/bloc/podcast/queue_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/state/queue_event_state.dart';
import 'package:anytime/ui/widgets/episode_tile.dart';
import 'package:anytime/ui/widgets/platform_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

/// Represents an item in the grouped timeline list — either a date header or
/// an episode tile.
enum _TimelineItemType { header, episode }

/// A single display item in the flat timeline list.
class _TimelineItem {
  final _TimelineItemType type;
  final String? headerText;
  final Episode? episode;

  _TimelineItem.header(this.headerText)
      : type = _TimelineItemType.header,
        episode = null;

  _TimelineItem.episode(this.episode)
      : type = _TimelineItemType.episode,
        headerText = null;
}

/// Displays a paginated, date-grouped timeline of all episodes from subscribed
/// podcasts. Supports:
///
/// - **Infinite scroll**: loads more episodes when the user scrolls near the
///   bottom of the list.
/// - **Date jump**: tap any date header to open a date picker and jump the
///   timeline to that day.
/// - **Manual refresh**: tap the refresh button in the toolbar.
class Timeline extends StatefulWidget {
  const Timeline({
    super.key,
  });

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  @override
  void initState() {
    super.initState();

    final bloc = Provider.of<TimelineBloc>(context, listen: false);
    if (!bloc.hasData) {
      bloc.event(TimelineEvent.refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<TimelineBloc>(context);

    return StreamBuilder<BlocState>(
      stream: bloc.state,
      builder: (BuildContext context, AsyncSnapshot<BlocState> snapshot) {
        final state = snapshot.data;

        // LoadingMore — keep showing the current list
        if (state is BlocBackgroundLoadingState) {
          return _buildTimelineList(
            context,
            state.data as List<Episode>?,
            bloc,
            isLoadingMore: true,
          );
        }

        if (state is BlocPopulatedState) {
          // No auto-scroll needed — when a date filter is active, only a
          // single day's episodes are shown so the list naturally starts
          // at the top.
          return _buildTimelineList(
            context,
            state.results as List<Episode>?,
            bloc,
            isLoadingMore: false,
          );
        }

        if (state is BlocLoadingState) {
          // First-time load or refreshing — show spinner.
          // If there's existing data underneath (from refresh), show it.
          final existing = state.data as List<Episode>?;
          if (existing != null && existing.isNotEmpty) {
            return _buildTimelineList(context, existing, bloc, isLoadingMore: true);
          }
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                PlatformProgressIndicator(),
              ],
            ),
          );
        }

        if (state is BlocErrorState) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load timeline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => bloc.event(TimelineEvent.refresh),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline list builder
  // ---------------------------------------------------------------------------

  /// Builds the grouped timeline sliver list, toolbar, and optional
  /// loading‑more indicator.
  Widget _buildTimelineList(
    BuildContext context,
    List<Episode>? episodes,
    TimelineBloc bloc, {
    bool isLoadingMore = false,
  }) {
    if (episodes == null || episodes.isEmpty) {
      final hasHidden = bloc.hasHiddenPlayed;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                hasHidden ? Icons.visibility_off : Icons.timeline,
                size: 75,
                color: Theme.of(context).primaryColor,
              ),
              const Padding(padding: EdgeInsets.only(top: 16.0)),
              Text(
                hasHidden
                    ? 'All episodes are played. Tap the visibility icon above to show them.'
                    : L.of(context)!.no_episodes_message,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildGroupedItems(episodes);

    final queueBloc = Provider.of<QueueBloc>(context);

    return StreamBuilder<QueueState>(
      stream: queueBloc.queue,
      builder: (context, snapshot) {
        final hasFilter = bloc.dateFilter != null;
        final toolbarOffset = hasFilter ? 1 : 0;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              // Index 0: optional filter‑clear banner
              if (hasFilter && index == 0) {
                return _buildFilterBanner(context, bloc);
              }

              // Next item: toolbar (sort + refresh)
              if (index == toolbarOffset) {
                return _buildToolbar(context, bloc, isLoadingMore);
              }

              final itemIndex = index - (toolbarOffset + 1);

              // If we've emitted all items, show the loading‑more indicator
              // at the bottom and trigger the next page load.
              if (itemIndex >= items.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  bloc.loadMore();
                });
                return _buildLoadingMoreIndicator();
              }

              final item = items[itemIndex];

              if (item.type == _TimelineItemType.header) {
                return _buildHeader(context, item.headerText!, bloc);
              }

              final episode = item.episode!;
              var queued = false;

              if (snapshot.hasData) {
                queued = snapshot.data!.queue.any((element) => element.guid == episode.guid);
              }

              return EpisodeTile(
                episode: episode,
                download: true,
                play: true,
                queued: queued,
              );
            },
            childCount: (hasFilter ? 1 : 0) + 1 + items.length + (bloc.hasMore ? 1 : 0),
            addAutomaticKeepAlives: false,
          ),
        );
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.0),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  /// Builds a banner shown when a date filter is active.
  Widget _buildFilterBanner(BuildContext context, TimelineBloc bloc) {
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().format(bloc.dateFilter!);

    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          Icon(Icons.filter_alt, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing $dateStr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => bloc.clearDateFilter(),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the toolbar row with refresh button and show-played toggle.
  Widget _buildToolbar(BuildContext context, TimelineBloc bloc, bool isLoadingMore) {
    final theme = Theme.of(context);
    final showPlayed = bloc.showPlayed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          // Loading indicator during refresh
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),

          // Show/hide played episodes toggle
          Semantics(
            button: true,
            child: IconButton(
              icon: Icon(
                showPlayed ? Icons.visibility : Icons.visibility_off,
                size: 20.0,
                color: showPlayed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
              ),
              tooltip: showPlayed ? 'Hide played episodes' : 'Show played episodes',
              onPressed: () => bloc.event(TimelineEvent.toggleShowPlayed),
              visualDensity: VisualDensity.compact,
            ),
          ),

          // Refresh button
          Semantics(
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.refresh,
                size: 20.0,
                color: theme.colorScheme.secondary,
              ),
              tooltip: 'Refresh timeline',
              onPressed: () => bloc.event(TimelineEvent.refresh),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date grouping
  // ---------------------------------------------------------------------------

  /// Groups [episodes] by date bucket and returns a flat list of display items.
  List<_TimelineItem> _buildGroupedItems(List<Episode> episodes) {
    final items = <_TimelineItem>[];
    String? lastBucket;

    for (final episode in episodes) {
      final bucket = _dateBucket(episode.publicationDate);

      if (bucket != lastBucket) {
        items.add(_TimelineItem.header(bucket));
        lastBucket = bucket;
      }

      items.add(_TimelineItem.episode(episode));
    }

    return items;
  }

  /// Returns a human-readable date bucket label for the given [date].
  String _dateBucket(DateTime? date) {
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'This Week';

    return DateFormat.yMMMd().format(date);
  }

  // ---------------------------------------------------------------------------
  // Header (tappable — opens date picker)
  // ---------------------------------------------------------------------------

  /// Builds a date-section header. Tapping it opens a [showDatePicker] so the
  /// user can jump to another date in the timeline.
  Widget _buildHeader(BuildContext context, String text, TimelineBloc bloc) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showDatePicker(context, bloc),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 14.0,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a [showDatePicker]. When the user picks a date, calls
  /// [TimelineBloc.jumpToDate] to load enough pages and scroll there.
  Future<void> _showDatePicker(BuildContext context, TimelineBloc bloc) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Jump to date in timeline',
    );

    if (picked != null && context.mounted) {
      // Use start-of-day so the entire selected day is included.
      // (Using 23:59:59 would exclude most episodes from that day.)
      final target = DateTime(picked.year, picked.month, picked.day);
      bloc.jumpToDate(target);
    }
  }
}
