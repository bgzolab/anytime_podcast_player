// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/core/utils.dart';
import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/state/bookmark_state.dart';
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
  List<Bookmark>? _bookmarks;
  bool _error = false;
  StreamSubscription<BlocState<List<Bookmark>>>? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
    _subscription ??= bookmarkBloc.state.listen(_onState);

    _fetchForCurrentEpisode();
  }

  /// Only accepts episode-scoped states for the episode currently on screen;
  /// the shared BLoC's all-bookmarks states must not be rendered here.
  void _onState(BlocState<List<Bookmark>> state) {
    if (!mounted) return;

    if (state is BookmarkListState &&
        state.scope == BookmarkScope.episode &&
        state.episodeGuid == _currentEpisodeGuid) {
      setState(() {
        _error = false;
        _bookmarks = state.results ?? const <Bookmark>[];
      });
    } else if (state is BookmarkErrorState &&
        state.scope == BookmarkScope.episode &&
        state.episodeGuid == _currentEpisodeGuid) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _fetchForCurrentEpisode() {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
    final episode = audioBloc.nowPlaying?.valueOrNull;

    if (episode != null && episode.guid != _currentEpisodeGuid) {
      _currentEpisodeGuid = episode.guid;
      // Don't keep showing the previous episode's bookmarks: they belong to a
      // different episode and tapping one would seek the wrong position.
      _bookmarks = null;
      _error = false;
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
        final episode = episodeSnapshot.data;

        if (episode != null && episode.guid != _currentEpisodeGuid) {
          _currentEpisodeGuid = episode.guid;
          // Clear the previous episode's bookmarks while the new fetch is in
          // flight; otherwise they can be tapped and seek the wrong position.
          _bookmarks = null;
          _error = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            bookmarkBloc.event(BookmarkFetchByEpisodeEvent(episodeGuid: episode.guid));
          });
        }

        if (episode == null) return _buildEmptyState(context);

        if (_error) {
          return Center(child: Text(L.of(context)!.bookmarks_load_failed));
        }

        final bookmarks = _bookmarks;

        if (bookmarks == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bookmarks.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildList(context, bookmarks, audioBloc, bookmarkBloc);
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
          child: Card(
            child: ListTile(
              leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
              title: Text(
                formatPlaybackPosition(Duration(milliseconds: bookmark.positionMs), includeHours: true),
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
          ),
        );
      },
    );
  }
}
