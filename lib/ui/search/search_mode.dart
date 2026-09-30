// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Defines the search context for each tab in the bottom navigation bar.
///
/// Each mode determines what data is searched and how results are displayed.
enum SearchMode {
  /// Search all local episodes by title (Home/Timeline tab).
  home,

  /// Search online via iTunes/PodcastIndex API (Discovery tab).
  discovery,

  /// Search bookmarks (My tab / Bookmarks page).
  my,

  /// Search downloaded episodes (Downloads page).
  download,
}
