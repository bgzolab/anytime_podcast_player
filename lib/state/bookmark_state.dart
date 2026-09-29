// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/state/bloc_state.dart';

/// The query scope a bookmark state belongs to.
enum BookmarkScope { all, episode }

/// Populated bookmark state tagged with the scope it was loaded for.
///
/// [BookmarksPage] and [BookmarkView] share a single [BookmarkBloc] and its
/// state stream; tagging each state lets a view ignore results that belong to
/// the other scope instead of rendering them.
class BookmarkListState extends BlocPopulatedState<List<Bookmark>> {
  final BookmarkScope scope;
  final String? episodeGuid;

  BookmarkListState({
    required List<Bookmark> results,
    required this.scope,
    this.episodeGuid,
  }) : super(results: results);
}

/// Error state tagged with the scope it failed for.
class BookmarkErrorState extends BlocErrorState<List<Bookmark>> {
  final BookmarkScope scope;
  final String? episodeGuid;

  BookmarkErrorState({
    required this.scope,
    this.episodeGuid,
    super.error,
  });
}
