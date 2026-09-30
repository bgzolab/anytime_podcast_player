// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/timeline/timeline_bloc.dart';
import 'package:anytime/bloc/podcast/queue_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/state/queue_event_state.dart';
import 'package:anytime/ui/widgets/compact_episode_tile.dart';
import 'package:anytime/ui/widgets/platform_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

/// Displays a paginated timeline of all episodes from subscribed
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
                      L.of(context)!.timeline_failed_to_load,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => bloc.event(TimelineEvent.refresh),
                      child: Text(L.of(context)!.retry_button_label),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Unknown/default state (e.g. before the first load): keep showing a
        // spinner rather than a blank screen.
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
                color: Theme.of(context).colorScheme.primary,
              ),
              const Padding(padding: EdgeInsets.only(top: 16.0)),
              Text(
                hasHidden ? L.of(context)!.timeline_all_played_message : L.of(context)!.no_episodes_message,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final queueBloc = Provider.of<QueueBloc>(context);

    return StreamBuilder<QueueState>(
      stream: queueBloc.queue,
      builder: (context, snapshot) {
        final hasFilter = bloc.dateFilter != null;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              // Index 0: optional filter‑clear banner
              if (hasFilter && index == 0) {
                return _buildFilterBanner(context, bloc);
              }

              final itemIndex = index - (hasFilter ? 1 : 0);

              // If we've emitted all items, show the loading‑more indicator
              // at the bottom and trigger the next page load.
              if (itemIndex >= episodes.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  bloc.loadMore();
                });
                return _buildLoadingMoreIndicator();
              }

              final episode = episodes[itemIndex];
              final isFirst = itemIndex == 0;
              final isLast = itemIndex == episodes.length - 1;
              var queued = false;

              if (snapshot.hasData) {
                queued = snapshot.data!.queue.any((element) => element.guid == episode.guid);
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: isFirst && isLast
                      ? BorderRadius.circular(12)
                      : BorderRadius.only(
                          topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
                          topRight: isFirst ? const Radius.circular(12) : Radius.zero,
                          bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
                        ),
                ),
                child: CompactEpisodeTile(
                  episode: episode,
                  download: true,
                  play: true,
                  queued: queued,
                  showPodcastName: true,
                ),
              );
            },
            childCount: (hasFilter ? 1 : 0) + episodes.length + (bloc.hasMore ? 1 : 0),
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
    final dateStr = DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(bloc.dateFilter!);

    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          Icon(Icons.filter_alt, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              L.of(context)!.timeline_showing_date(dateStr),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => bloc.clearDateFilter(),
            icon: const Icon(Icons.close, size: 16),
            label: Text(L.of(context)!.clear_button_label),
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
}
