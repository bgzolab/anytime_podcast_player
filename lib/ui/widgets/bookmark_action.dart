// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens [bookmark] for playback.
///
/// When the bookmark's episode is already playing the player simply seeks to
/// the bookmarked position; otherwise the episode is loaded and starts from
/// that position. Shared by the bookmarks overview and the bookmark search
/// results so both behave identically.
Future<void> openBookmark(BuildContext context, Bookmark bookmark) async {
  final audioBloc = Provider.of<AudioBloc>(context, listen: false);
  final nowPlaying = audioBloc.nowPlaying?.valueOrNull;

  if (nowPlaying?.guid == bookmark.episodeGuid) {
    audioBloc.transitionPosition(bookmark.positionMs / 1000.0);

    return;
  }

  final repository = Provider.of<Repository>(context, listen: false);
  final episode = await repository.findEpisodeByGuid(bookmark.episodeGuid);

  if (episode == null) {
    // The episode may have been removed since the bookmark was created.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context)!.bookmark_episode_missing)),
      );
    }

    return;
  }

  episode.position = bookmark.positionMs;
  audioBloc.play(episode);
}
