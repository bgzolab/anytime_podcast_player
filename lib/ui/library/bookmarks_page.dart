// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

/// Displays all bookmarked episodes grouped by podcast → episode.
///
/// Returns slivers for embedding inside the parent [CustomScrollView].
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
      bookmarkBloc.event(BookmarkFetchAllEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);

    return StreamBuilder<BlocState<List<Bookmark>>>(
      stream: bookmarkBloc.state,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data is BlocLoadingState) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data is BlocErrorState) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(L.of(context)!.bookmarks_load_failed)),
          );
        }

        final state = snapshot.data;
        final bookmarks = (state is BlocPopulatedState<List<Bookmark>>) ? state.results ?? [] : <Bookmark>[];

        if (bookmarks.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmarks_outlined, size: 64.0, color: Theme.of(context).disabledColor),
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

        return _buildSliverList(context, bookmarks, bookmarkBloc);
      },
    );
  }

  Widget _buildSliverList(
    BuildContext context,
    List<Bookmark> bookmarks,
    BookmarkBloc bookmarkBloc,
  ) {
    // Group: podcastName → episodeGuid → _EpisodeBookmarks
    final podcastMap = <String, Map<String, _EpisodeBookmarks>>{};
    for (final b in bookmarks) {
      final podcastName = b.podcastName ?? L.of(context)!.unknown_podcast;
      podcastMap
          .putIfAbsent(podcastName, () => {})
          .putIfAbsent(
              b.episodeGuid, () => _EpisodeBookmarks(episodeTitle: b.episodeTitle ?? L.of(context)!.unknown_episode))
          .bookmarks
          .add(b);
    }

    final podcastNames = podcastMap.keys.toList()..sort();

    // Build a flat list of display items for the SliverList.
    final items = <_DisplayItem>[];
    for (final podcastName in podcastNames) {
      final episodeMap = podcastMap[podcastName]!;
      final episodes = episodeMap.values.toList();
      final totalBookmarks = episodes.fold(0, (sum, ep) => sum + ep.bookmarks.length);
      items.add(_DisplayItem.podcastHeader(podcastName, episodes.length, totalBookmarks));

      for (final ep in episodes) {
        items.add(_DisplayItem.episode(ep));
        for (final bookmark in ep.bookmarks) {
          items.add(_DisplayItem.bookmark(bookmark));
        }
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final item = items[index];

          if (item.isPodcastHeader) {
            return _PodcastHeaderTile(
              podcastName: item.podcastName!,
              episodeCount: item.episodeCount!,
              bookmarkCount: item.bookmarkCount!,
            );
          }

          if (item.isEpisode) {
            return _EpisodeTile(episodeBookmarks: item.episodeBookmarks!);
          }

          // Bookmark tile
          return _BookmarkTile(
            bookmark: item.bookmark!,
            onDelete: () => bookmarkBloc.event(BookmarkDeleteEvent(bookmark: item.bookmark!)),
          );
        },
        childCount: items.length,
      ),
    );
  }
}

/// A flat list item that can be a podcast header, episode, or bookmark.
class _DisplayItem {
  final int type; // 0 = podcast header, 1 = episode, 2 = bookmark
  final String? podcastName;
  final int? episodeCount;
  final int? bookmarkCount;
  final _EpisodeBookmarks? episodeBookmarks;
  final Bookmark? bookmark;

  _DisplayItem.podcastHeader(this.podcastName, this.episodeCount, this.bookmarkCount)
      : type = 0,
        episodeBookmarks = null,
        bookmark = null;

  _DisplayItem.episode(this.episodeBookmarks)
      : type = 1,
        podcastName = null,
        episodeCount = null,
        bookmarkCount = null,
        bookmark = null;

  _DisplayItem.bookmark(this.bookmark)
      : type = 2,
        podcastName = null,
        episodeCount = null,
        bookmarkCount = null,
        episodeBookmarks = null;

  bool get isPodcastHeader => type == 0;
  bool get isEpisode => type == 1;
}

class _EpisodeBookmarks {
  final String episodeTitle;
  final List<Bookmark> bookmarks = [];

  _EpisodeBookmarks({required this.episodeTitle});
}

class _PodcastHeaderTile extends StatelessWidget {
  final String podcastName;
  final int episodeCount;
  final int bookmarkCount;

  const _PodcastHeaderTile({
    required this.podcastName,
    required this.episodeCount,
    required this.bookmarkCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: Row(
        children: [
          Icon(Icons.podcasts, size: 20.0, color: theme.primaryColor),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              podcastName,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$episodeCount ep · $bookmarkCount bm',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final _EpisodeBookmarks episodeBookmarks;

  const _EpisodeTile({required this.episodeBookmarks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = episodeBookmarks.bookmarks.length;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Row(
        children: [
          Icon(Icons.bookmark, size: 18.0, color: theme.primaryColor),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              episodeBookmarks.episodeTitle,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count bm',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onDelete;

  const _BookmarkTile({required this.bookmark, required this.onDelete});

  String _formatPosition(int positionMs) {
    final duration = Duration(milliseconds: positionMs);
    String twoDigits(int n) => n >= 10 ? '$n' : '0$n';
    var h = twoDigits(duration.inHours.toInt());
    var m = twoDigits(duration.inMinutes.remainder(60).toInt());
    var s = twoDigits(duration.inSeconds.remainder(60).toInt());
    return '$h:$m:$s';
  }

  String _formatDate(BuildContext context, DateTime date) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date);

  /// Plays the bookmark: seeks when its episode is already playing, otherwise
  /// starts that episode from the bookmarked position.
  Future<void> _openBookmark(BuildContext context) async {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final nowPlaying = audioBloc.nowPlaying?.valueOrNull;

    if (nowPlaying?.guid == bookmark.episodeGuid) {
      audioBloc.transitionPosition(bookmark.positionMs / 1000.0);

      return;
    }

    final repository = Provider.of<Repository>(context, listen: false);
    final episode = await repository.findEpisodeByGuid(bookmark.episodeGuid);

    if (episode == null) return;

    episode.position = bookmark.positionMs;
    audioBloc.play(episode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('bm_${bookmark.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        color: Colors.red,
        child: Semantics(
          label: L.of(context)!.bookmark_delete_label,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 42.0),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.access_time, size: 18.0, color: theme.primaryColor),
          title: Text(
            _formatPosition(bookmark.positionMs),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bookmark.note != null && bookmark.note!.isNotEmpty)
                Text(bookmark.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                _formatDate(context, bookmark.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline, size: 22.0),
            tooltip: L.of(context)!.bookmark_seek_label(_formatPosition(bookmark.positionMs)),
            onPressed: () => _openBookmark(context),
          ),
          onTap: () => _openBookmark(context),
        ),
      ),
    );
  }
}
