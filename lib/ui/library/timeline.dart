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

/// Displays all episodes from subscribed podcasts in a date-grouped timeline,
/// with a toggle between newest-first and oldest-first sort order.
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

    bloc.event(TimelineEvent.fetch);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<TimelineBloc>(context);

    return StreamBuilder<BlocState>(
      stream: bloc.state,
      builder: (BuildContext context, AsyncSnapshot<BlocState> snapshot) {
        final state = snapshot.data;

        if (state is BlocPopulatedState<List<Episode>>) {
          return _buildTimelineList(context, state.results, bloc);
        } else {
          if (state is BlocLoadingState) {
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
          } else if (state is BlocErrorState) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Text('ERROR'),
            );
          }

          return SliverFillRemaining(
            hasScrollBody: false,
            child: Container(),
          );
        }
      },
    );
  }

  /// Builds the grouped timeline list. Shows an empty-state message when
  /// [episodes] is null or empty.
  Widget _buildTimelineList(BuildContext context, List<Episode>? episodes, TimelineBloc bloc) {
    if (episodes == null || episodes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.timeline,
                size: 75,
                color: Theme.of(context).primaryColor,
              ),
              const Padding(padding: EdgeInsets.only(top: 16.0)),
              Text(
                L.of(context)!.no_episodes_message,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build flat list of grouped items (excluding the sort toggle row).
    final items = _buildGroupedItems(episodes);

    final queueBloc = Provider.of<QueueBloc>(context);

    return StreamBuilder<QueueState>(
      stream: queueBloc.queue,
      builder: (context, snapshot) {
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              // Index 0: sort toggle row
              if (index == 0) {
                return _buildSortToggle(context, bloc);
              }

              final item = items[index - 1];

              if (item.type == _TimelineItemType.header) {
                return _buildHeader(context, item.headerText!);
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
            childCount: 1 + items.length,
            addAutomaticKeepAlives: false,
          ),
        );
      },
    );
  }

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

  /// Builds the sort toggle row displayed at the top of the timeline.
  Widget _buildSortToggle(BuildContext context, TimelineBloc bloc) {
    final theme = Theme.of(context);
    final isDescending = bloc.sortDescending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Semantics(
            button: true,
            child: InkWell(
              onTap: () {
                bloc.event(
                  isDescending ? TimelineEvent.sortOldestFirst : TimelineEvent.sortNewestFirst,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isDescending ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16.0,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      isDescending
                          ? L.of(context)!.episode_sort_latest_first_label
                          : L.of(context)!.episode_sort_earliest_first_label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a date-section header widget.
  Widget _buildHeader(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
