// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:anytime/bloc/search/search_bloc.dart';
import 'package:anytime/bloc/search/search_state_event.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/ui/search/search_mode.dart';
import 'package:anytime/ui/search/search_results.dart';
import 'package:anytime/ui/widgets/bookmark_action.dart';
import 'package:anytime/ui/widgets/episode_tile.dart';
import 'package:anytime/ui/widgets/podcast_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// This widget renders the search bar and allows the user to search for content
/// based on the current [SearchMode].
class Search extends StatefulWidget {
  final String? searchTerm;
  final SearchMode mode;
  final Repository? repository;

  const Search({
    super.key,
    this.searchTerm,
    this.mode = SearchMode.discovery,
    this.repository,
  });

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  SearchMode get _mode => widget.mode;

  // Local search state for non-discovery modes.
  List<Episode> _episodeResults = [];
  List<Podcast> _podcastResults = [];
  List<Bookmark> _bookmarkResults = [];
  bool _isLocalSearching = false;
  bool _hasSearched = false;

  /// Incremented for every local search so a slower, older query cannot
  /// overwrite the results of a newer one.
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();

    _searchFocusNode = FocusNode();
    _searchController = TextEditingController();

    if (_mode == SearchMode.discovery) {
      final bloc = Provider.of<SearchBloc>(context, listen: false);
      bloc.search(SearchClearEvent());

      if (widget.searchTerm != null) {
        bloc.search(SearchTermEvent(widget.searchTerm!));
        _searchController.text = widget.searchTerm!;
      }
    } else if (widget.searchTerm != null) {
      _searchController.text = widget.searchTerm!;
      _performLocalSearch(widget.searchTerm!);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _performLocalSearch(String term) async {
    final generation = ++_searchGeneration;

    if (term.isEmpty) {
      setState(() {
        _episodeResults = [];
        _podcastResults = [];
        _bookmarkResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLocalSearching = true;
      _hasSearched = true;
    });

    final repository = widget.repository ?? Provider.of<Repository>(context, listen: false);

    try {
      switch (_mode) {
        case SearchMode.timeline:
          final results = await repository.searchEpisodes(term);
          _applyLocalResults(generation, episodes: results);
          break;
        case SearchMode.library:
          final results = await repository.searchPodcasts(term);
          _applyLocalResults(generation, podcasts: results);
          break;
        case SearchMode.downloads:
          final results = await repository.searchDownloads(term);
          _applyLocalResults(generation, episodes: results);
          break;
        case SearchMode.bookmarks:
          final results = await repository.searchBookmarks(term);
          _applyLocalResults(generation, bookmarks: results);
          break;
        case SearchMode.discovery:
          // Handled by SearchBloc
          break;
      }
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _episodeResults = [];
        _podcastResults = [];
        _bookmarkResults = [];
        _isLocalSearching = false;
      });
    }
  }

  /// Applies local search results only when [generation] is still the latest
  /// request, so a slow earlier search cannot overwrite a newer one.
  void _applyLocalResults(
    int generation, {
    List<Episode>? episodes,
    List<Podcast>? podcasts,
    List<Bookmark>? bookmarks,
  }) {
    if (!mounted || generation != _searchGeneration) return;

    setState(() {
      if (episodes != null) _episodeResults = episodes;
      if (podcasts != null) _podcastResults = podcasts;
      if (bookmarks != null) _bookmarkResults = bookmarks;
      _isLocalSearching = false;
    });
  }

  String _getHintText(BuildContext context) {
    switch (_mode) {
      case SearchMode.timeline:
        return L.of(context)!.search_episodes_hint;
      case SearchMode.library:
        return L.of(context)!.search_podcasts_hint;
      case SearchMode.discovery:
        return L.of(context)!.search_for_podcasts_hint;
      case SearchMode.downloads:
        return L.of(context)!.search_downloads_hint;
      case SearchMode.bookmarks:
        return L.of(context)!.search_bookmarks_hint;
    }
  }

  void _onSubmitted(String value) {
    SemanticsService.announce(L.of(context)!.semantic_announce_searching, TextDirection.ltr);

    if (_mode == SearchMode.discovery) {
      final bloc = Provider.of<SearchBloc>(context, listen: false);
      bloc.search(SearchTermEvent(value));
    } else {
      _performLocalSearch(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            leading: IconButton(
              tooltip: L.of(context)!.search_back_button_label,
              icon: Platform.isAndroid
                  ? Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).appBarTheme.foregroundColor,
                      semanticLabel: L.of(context)!.search_back_button_label,
                    )
                  : Icon(
                      Icons.arrow_back_ios,
                      semanticLabel: L.of(context)!.search_back_button_label,
                    ),
              onPressed: () => Navigator.pop(context),
            ),
            title: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: widget.searchTerm != null ? false : true,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _getHintText(context),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                    color: Theme.of(context).primaryIconTheme.color,
                    fontSize: 18.0,
                    decorationColor: Theme.of(context).scaffoldBackgroundColor),
                onSubmitted: _onSubmitted),
            floating: false,
            pinned: true,
            snap: false,
            actions: <Widget>[
              IconButton(
                tooltip: L.of(context)!.clear_search_button_label,
                icon: Icon(
                  Icons.clear,
                  semanticLabel: L.of(context)!.clear_search_button_label,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _episodeResults = [];
                    _podcastResults = [];
                    _bookmarkResults = [];
                    _hasSearched = false;
                  });
                  if (_mode == SearchMode.discovery) {
                    final bloc = Provider.of<SearchBloc>(context, listen: false);
                    bloc.search(SearchClearEvent());
                  }
                  FocusScope.of(context).requestFocus(_searchFocusNode);
                  SystemChannels.textInput.invokeMethod<String>('TextInput.show');
                },
              ),
            ],
          ),
          if (_mode == SearchMode.discovery) _buildDiscoveryResults() else _buildLocalResults(),
        ],
      ),
    );
  }

  Widget _buildDiscoveryResults() {
    final bloc = Provider.of<SearchBloc>(context);
    return SearchResults(data: bloc.results!);
  }

  Widget _buildLocalResults() {
    if (_isLocalSearching) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasSearched) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(),
      );
    }

    switch (_mode) {
      case SearchMode.timeline:
      case SearchMode.downloads:
        return _buildEpisodeResults();
      case SearchMode.library:
        return _buildPodcastResults();
      case SearchMode.bookmarks:
        return _buildBookmarkResults();
      case SearchMode.discovery:
        return _buildDiscoveryResults();
    }
  }

  Widget _buildEpisodeResults() {
    if (_episodeResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(
          Icons.search,
          _mode == SearchMode.downloads ? L.of(context)!.no_downloads_found : L.of(context)!.no_episodes_found,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final episode = _episodeResults[index];
          return EpisodeTile(
            episode: episode,
            download: false,
            play: true,
          );
        },
        childCount: _episodeResults.length,
      ),
    );
  }

  Widget _buildPodcastResults() {
    if (_podcastResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(
          Icons.search,
          L.of(context)!.no_podcasts_found,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final podcast = _podcastResults[index];
          return PodcastTile(podcast: podcast);
        },
        childCount: _podcastResults.length,
      ),
    );
  }

  Widget _buildBookmarkResults() {
    if (_bookmarkResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(
          Icons.bookmarks_outlined,
          L.of(context)!.no_bookmarks_found,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final bookmark = _bookmarkResults[index];
          return _BookmarkSearchTile(bookmark: bookmark);
        },
        childCount: _bookmarkResults.length,
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 75,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16.0),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A tile for displaying a bookmark in search results.
class _BookmarkSearchTile extends StatelessWidget {
  final Bookmark bookmark;

  const _BookmarkSearchTile({
    required this.bookmark,
  });

  @override
  Widget build(BuildContext context) {
    final position = Duration(milliseconds: bookmark.positionMs);
    final hours = position.inHours;
    final minutes = position.inMinutes.remainder(60);
    final seconds = position.inSeconds.remainder(60);
    final positionStr = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return ListTile(
      leading: const Icon(Icons.bookmark, size: 32),
      title: Text(
        bookmark.episodeTitle ?? L.of(context)!.unknown_episode,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (bookmark.podcastName != null) bookmark.podcastName!,
          positionStr,
          if (bookmark.note != null && bookmark.note!.isNotEmpty) bookmark.note!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openBookmark(context, bookmark),
    );
  }
}
