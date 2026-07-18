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

/// Displays bookmarks for the **currently playing episode** in the Now Playing
/// bottom sheet, alongside "UP NEXT" and "TRANSCRIPT".
class BookmarkView extends StatefulWidget {
  const BookmarkView({super.key});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView> {
  String? _currentEpisodeGuid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchForCurrentEpisode();
  }

  void _fetchForCurrentEpisode() {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
    final episode = audioBloc.nowPlaying?.value;

    if (episode != null && episode.guid != _currentEpisodeGuid) {
      _currentEpisodeGuid = episode.guid;
      bookmarkBloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: episode.guid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);

    return StreamBuilder(
      stream: audioBloc.nowPlaying,
      builder: (context, episodeSnapshot) {
        // Re-fetch when episode changes
        if (episodeSnapshot.hasData && episodeSnapshot.data!.guid != _currentEpisodeGuid) {
          _currentEpisodeGuid = episodeSnapshot.data!.guid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bookmarkBloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: episodeSnapshot.data!.guid));
          });
        }

        return StreamBuilder<BlocState<List<Bookmark>>>(
          stream: bookmarkBloc.state,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data is BlocLoadingState) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.data is BlocErrorState) {
              return Center(child: Text(L.of(context)!.no_bookmarks_message));
            }

            final state = snapshot.data;
            final bookmarks = (state is BlocPopulatedState<List<Bookmark>>) ? state.results ?? [] : <Bookmark>[];

            if (bookmarks.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildList(context, bookmarks, audioBloc, bookmarkBloc);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 48.0, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12.0),
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

  Widget _buildList(
    BuildContext context,
    List<Bookmark> bookmarks,
    AudioBloc audioBloc,
    BookmarkBloc bookmarkBloc,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
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
            leading: Icon(Icons.bookmark, color: Theme.of(context).primaryColor),
            title: Text(
              _formatPosition(bookmark.positionMs),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            subtitle: bookmark.note != null && bookmark.note!.isNotEmpty
                ? Text(bookmark.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () {
                audioBloc.transitionPosition(bookmark.positionMs / 1000.0);
              },
            ),
            onTap: () {
              audioBloc.transitionPosition(bookmark.positionMs / 1000.0);
            },
          ),
        );
      },
    );
  }

  String _formatPosition(int positionMs) {
    final duration = Duration(milliseconds: positionMs);
    String twoDigits(int n) => n >= 10 ? '$n' : '0$n';
    var h = twoDigits(duration.inHours.toInt());
    var m = twoDigits(duration.inMinutes.remainder(60).toInt());
    var s = twoDigits(duration.inSeconds.remainder(60).toInt());
    return '$h:$m:$s';
  }
}
