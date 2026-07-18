// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract class LibraryState {}

class LibraryRefreshingState extends LibraryState {}

class LibraryReadyState extends LibraryState {}

class LibraryUpdatedState extends LibraryState {}

/// Progress update emitted during [PodcastService.refreshFeedsWithProgress].
class RefreshProgress {
  final int total;
  final int completed;
  final String currentSource;
  final bool finished;

  const RefreshProgress({
    required this.total,
    required this.completed,
    required this.currentSource,
    this.finished = false,
  });
}
