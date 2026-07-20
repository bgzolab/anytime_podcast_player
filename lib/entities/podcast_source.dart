// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum PodcastSource {
  audio(id: 0),
  youtube(id: 1);

  const PodcastSource({required this.id});

  final int id;

  int toValue() => id;

  static PodcastSource fromValue(int v) {
    switch (v) {
      case 1:
        return PodcastSource.youtube;
      default:
        return PodcastSource.audio;
    }
  }
}
