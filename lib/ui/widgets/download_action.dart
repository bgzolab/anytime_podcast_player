// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Starts downloading [episode].
///
/// On platforms without a download manager (e.g. Windows) the user is told
/// that downloads are unsupported instead of the request failing silently
/// after downloading chapters and transcripts. Shared by the episode tiles
/// and the player transport controls so every entry point behaves the same.
void startEpisodeDownload(BuildContext context, PodcastBloc podcastBloc, Episode episode) {
  if (!podcastBloc.downloadsSupported) {
    final message = L.of(context)!.downloads_not_supported;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

    // The SnackBar is a live region, which TalkBack announces on Android;
    // VoiceOver does not reliably announce live regions, so announce the
    // message explicitly on iOS to cover both screen readers.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
    }

    return;
  }

  podcastBloc.downloadEpisode(episode);
}
