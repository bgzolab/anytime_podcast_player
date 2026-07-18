// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A standalone page that displays all bookmarked episodes with their bookmarks.
///
/// Structure: Podcast → Episode → Bookmarks
/// - Top level: podcast names with episode count
/// - Second level: episodes within each podcast, showing bookmark count
/// - Third level (expandable): individual bookmarks with position, note, date
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  @override
  void initState() {
    super.initState();
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
    bookmarkBloc.event(BookmarkFetchAllEvent());
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(L.of(context)!.bookmarks_label),
      ),
      body: StreamBuilder<BlocState<List<Bookmark>>>(
        stream: bookmarkBloc.state,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data is BlocLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data is BlocErrorState) {
            return Center(
              child: Text(L.of(context)!.no_bookmarks_message),
            );
          }

          final state = snapshot.data;
          final bookmarks = (state is BlocPopulatedState<List<Bookmark>>) ? state.results ?? [] : <Bookmark>[];

          if (bookmarks.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildPodcastList(context, bookmarks, bookmarkBloc);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 64.0,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16.0),
            Text(
              L.of(context)!.no_bookmarks_message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Groups bookmarks by podcast → episode, then builds a two-level list.
  Widget _buildPodcastList(
    BuildContext context,
    List<Bookmark> bookmarks,
    BookmarkBloc bookmarkBloc,
  ) {
    // Group: podcastName → { episodeGuid → { episodeTitle, bookmarks[] } }
    final podcastMap = <String, Map<String, _EpisodeBookmarks>>{};
    for (final b in bookmarks) {
      final podcastName = b.podcastName ?? 'Unknown Podcast';
      final episodeGuid = b.episodeGuid;
      podcastMap
          .putIfAbsent(podcastName, () => {})
          .putIfAbsent(episodeGuid, () => _EpisodeBookmarks(episodeTitle: b.episodeTitle ?? 'Unknown Episode', episodeGuid: episodeGuid, podcastGuid: b.podcastGuid))
          .bookmarks
          .add(b);
    }

    final podcastNames = podcastMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80.0),
      itemCount: podcastNames.length,
      itemBuilder: (context, podcastIndex) {
        final podcastName = podcastNames[podcastIndex];
        final episodeMap = podcastMap[podcastName]!;
        final episodes = episodeMap.values.toList();

        return _PodcastExpansionTile(
          podcastName: podcastName,
          episodeCount: episodes.length,
          bookmarkCount: bookmarks.where((b) => (b.podcastName ?? 'Unknown Podcast') == podcastName).length,
          initiallyExpanded: podcastIndex == 0,
          episodes: episodes,
          bookmarkBloc: bookmarkBloc,
        );
      },
    );
  }
}

/// Groups bookmarks for a single episode.
class _EpisodeBookmarks {
  final String episodeTitle;
  final String episodeGuid;
  final String? podcastGuid;
  final List<Bookmark> bookmarks = [];

  _EpisodeBookmarks({
    required this.episodeTitle,
    required this.episodeGuid,
    this.podcastGuid,
  });
}

/// A podcast-level expansion tile containing episode tiles.
class _PodcastExpansionTile extends StatelessWidget {
  final String podcastName;
  final int episodeCount;
  final int bookmarkCount;
  final bool initiallyExpanded;
  final List<_EpisodeBookmarks> episodes;
  final BookmarkBloc bookmarkBloc;

  const _PodcastExpansionTile({
    required this.podcastName,
    required this.episodeCount,
    required this.bookmarkCount,
    required this.initiallyExpanded,
    required this.episodes,
    required this.bookmarkBloc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: Icon(Icons.podcasts, color: theme.primaryColor),
      title: Text(
        podcastName,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '$episodeCount ${episodeCount == 1 ? "episode" : "episodes"} · $bookmarkCount ${bookmarkCount == 1 ? "bookmark" : "bookmarks"}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
      ),
      initiallyExpanded: initiallyExpanded,
      children: episodes.map((ep) {
        return _EpisodeExpansionTile(
          episodeBookmarks: ep,
          bookmarkBloc: bookmarkBloc,
        );
      }).toList(),
    );
  }
}

/// An episode-level expansion tile showing bookmark count, expandable to individual bookmarks.
class _EpisodeExpansionTile extends StatelessWidget {
  final _EpisodeBookmarks episodeBookmarks;
  final BookmarkBloc bookmarkBloc;

  const _EpisodeExpansionTile({
    required this.episodeBookmarks,
    required this.bookmarkBloc,
  });

  String _formatPosition(int positionMs) {
    final duration = Duration(milliseconds: positionMs);
    String twoDigits(int n) => n >= 10 ? '$n' : '0$n';
    var h = twoDigits(duration.inHours.toInt());
    var m = twoDigits(duration.inMinutes.remainder(60).toInt());
    var s = twoDigits(duration.inSeconds.remainder(60).toInt());
    return '$h:$m:$s';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = episodeBookmarks.bookmarks.length;

    return ExpansionTile(
      leading: Icon(Icons.bookmark, color: theme.primaryColor),
      title: Text(
        episodeBookmarks.episodeTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$count ${count == 1 ? "bookmark" : "bookmarks"}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
      ),
      children: episodeBookmarks.bookmarks.map((bookmark) {
        return Dismissible(
          key: ValueKey('bm_${bookmark.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            bookmarkBloc.event(BookmarkDeleteEvent(bookmark: bookmark));
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16.0),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 56.0, right: 16.0),
            leading: Icon(Icons.access_time, size: 20.0, color: theme.primaryColor),
            title: Text(
              _formatPosition(bookmark.positionMs),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bookmark.note != null && bookmark.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      bookmark.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    _formatDate(bookmark.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: L.of(context)!.bookmark_seek_label(_formatPosition(bookmark.positionMs)),
              onPressed: () {
                final audioBloc = Provider.of<AudioBloc>(context, listen: false);
                audioBloc.transitionPosition(bookmark.positionMs / 1000.0);
              },
            ),
            onTap: () {
              final audioBloc = Provider.of<AudioBloc>(context, listen: false);
              audioBloc.transitionPosition(bookmark.positionMs / 1000.0);
            },
          ),
        );
      }).toList(),
    );
  }
}
