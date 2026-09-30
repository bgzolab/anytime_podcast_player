// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:flutter/material.dart';

/// Starts downloading [episode].
///
/// On platforms without a download manager (e.g. Windows) the user is told
/// that downloads are unsupported instead of the request failing silently
/// after downloading chapters and transcripts. Shared by the episode tiles
/// and the player transport controls so every entry point behaves the same.
void startEpisodeDownload(BuildContext context, PodcastBloc podcastBloc, Episode episode) {
  if (!podcastBloc.downloadsSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context)!.downloads_not_supported)),
    );

    return;
  }

  podcastBloc.downloadEpisode(episode);
}
