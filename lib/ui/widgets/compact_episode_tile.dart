// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/bloc/podcast/episode_bloc.dart';
import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/bloc/podcast/queue_bloc.dart';
import 'package:anytime/bloc/settings/settings_bloc.dart';
import 'package:anytime/entities/app_settings.dart';
import 'package:anytime/entities/downloadable.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/state/queue_event_state.dart';
import 'package:anytime/ui/podcast/episode_details.dart';
import 'package:anytime/ui/podcast/now_playing.dart';
import 'package:anytime/ui/widgets/episode_tile.dart';
import 'package:anytime/ui/widgets/tile_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

/// A compact episode tile with a spacious layout and borderless action buttons.
///
/// Used in the Timeline tab and PodcastEpisodeList. The [showPodcastName]
/// parameter controls whether the podcast name subtitle is displayed —
/// Timeline shows it (episodes come from many sources), while
/// PodcastEpisodeList hides it (already inside that podcast's context).
class CompactEpisodeTile extends StatelessWidget {
  final Episode episode;
  final bool download;
  final bool play;
  final bool queued;
  final bool playing;
  final bool showPodcastName;

  const CompactEpisodeTile({
    super.key,
    required this.episode,
    required this.download,
    required this.play,
    this.playing = false,
    this.queued = false,
    this.showPodcastName = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final episodeBloc = Provider.of<EpisodeBloc>(context);
    final queueBloc = Provider.of<QueueBloc>(context);

    final playedMuted = episode.played;
    final mutedTextColor = playedMuted ? colorScheme.onSurface.withValues(alpha: 0.6) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Image + Content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Thumbnail with progress bar
              ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    ColorFiltered(
                      colorFilter: playedMuted
                          ? const ColorFilter.mode(Color(0x99FFFFFF), BlendMode.lighten)
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: TileImage(
                        url: episode.thumbImageUrl ?? episode.imageUrl!,
                        size: 80.0,
                        highlight: episode.highlight,
                      ),
                    ),
                    SizedBox(
                      height: 5.0,
                      width: 80.0 * (episode.percentagePlayed / 100),
                      child: Container(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      episode.title!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(color: mutedTextColor),
                    ),
                    if (showPodcastName) ...<Widget>[
                      const SizedBox(height: 2.0),
                      Text(
                        episode.podcast ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 2.0),
                    EpisodeSubtitle(episode),
                  ],
                ),
              ),
            ],
          ),
          // Borderless action buttons
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: <Widget>[
                // Play / Pause
                Semantics(
                  container: true,
                  child: _BuildPlayButton(episode: episode),
                ),
                // Queue add / remove
                Semantics(
                  container: true,
                  child: IconButton(
                    iconSize: 28,
                    icon: Icon(
                      queued ? Icons.playlist_add_check : Icons.playlist_add,
                      semanticLabel:
                          queued ? L.of(context)!.semantics_remove_from_queue : L.of(context)!.semantics_add_to_queue,
                    ),
                    style: IconButton.styleFrom(padding: EdgeInsets.zero),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      if (queued) {
                        queueBloc.queueEvent(QueueRemoveEvent(episode: episode));
                      } else {
                        queueBloc.queueEvent(QueueAddEvent(episode: episode));
                      }
                    },
                  ),
                ),
                // Mark played / unplayed
                Semantics(
                  container: true,
                  child: IconButton(
                    iconSize: 28,
                    icon: Icon(
                      episode.played ? Icons.unpublished_outlined : Icons.check_circle_outline,
                      semanticLabel: episode.played
                          ? L.of(context)!.semantics_mark_episode_unplayed
                          : L.of(context)!.semantics_mark_episode_played,
                    ),
                    style: IconButton.styleFrom(padding: EdgeInsets.zero),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => episodeBloc.togglePlayed(episode),
                  ),
                ),
                // Episode details
                Semantics(
                  container: true,
                  child: IconButton(
                    iconSize: 28,
                    icon: Icon(
                      Icons.unfold_more_outlined,
                      semanticLabel: L.of(context)!.episode_details_button_label,
                    ),
                    style: IconButton.styleFrom(padding: EdgeInsets.zero),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => EpisodeDetails(episode: episode),
                      );
                    },
                  ),
                ),
                // Download
                if (download)
                  Semantics(
                    container: true,
                    child: _BuildDownloadButton(episode: episode),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Determines and renders the correct play/pause icon based on audio state.
class _BuildPlayButton extends StatelessWidget {
  final Episode episode;

  const _BuildPlayButton({required this.episode});

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final settings = Provider.of<SettingsBloc>(context, listen: false).currentSettings;

    return StreamBuilder<_PlayerControlState>(
      stream: Rx.combineLatest2(
        audioBloc.playingState!,
        audioBloc.nowPlaying!,
        (AudioState audioState, Episode? episode) => _PlayerControlState(audioState, episode),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return IconButton(
            iconSize: 28,
            icon: const Icon(Icons.play_arrow),
            style: IconButton.styleFrom(padding: EdgeInsets.zero),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              audioBloc.play(episode);
              _optionalShowNowPlaying(context, settings);
            },
          );
        }

        final audioState = snapshot.data!.audioState;
        final nowPlaying = snapshot.data!.episode;
        final isCurrentEpisode = nowPlaying?.guid == episode.guid;

        if (isCurrentEpisode) {
          if (audioState == AudioState.playing) {
            return IconButton(
              iconSize: 28,
              icon: Icon(Icons.pause, color: Theme.of(context).colorScheme.primary),
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
              visualDensity: VisualDensity.compact,
              onPressed: () => audioBloc.transitionState(TransitionState.pause),
            );
          } else if (audioState == AudioState.buffering) {
            return IconButton(
              iconSize: 28,
              icon: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
              visualDensity: VisualDensity.compact,
              onPressed: null,
            );
          } else if (audioState == AudioState.pausing) {
            return IconButton(
              iconSize: 28,
              icon: Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                audioBloc.transitionState(TransitionState.play);
                _optionalShowNowPlaying(context, settings);
              },
            );
          }
        }

        // Not the currently playing episode — allow play
        return IconButton(
          iconSize: 28,
          icon: const Icon(Icons.play_arrow),
          style: IconButton.styleFrom(padding: EdgeInsets.zero),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            audioBloc.play(episode);
            _optionalShowNowPlaying(context, settings);
          },
        );
      },
    );
  }

  void _optionalShowNowPlaying(BuildContext context, AppSettings settings) {
    if (settings.autoOpenNowPlaying) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const NowPlaying(),
          settings: const RouteSettings(name: 'nowplaying'),
          fullscreenDialog: false,
        ),
      );
    }
  }
}

/// Determines and renders the correct download icon based on download state.
class _BuildDownloadButton extends StatelessWidget {
  final Episode episode;

  const _BuildDownloadButton({required this.episode});

  @override
  Widget build(BuildContext context) {
    final podcastBloc = Provider.of<PodcastBloc>(context);
    final episodeBloc = Provider.of<EpisodeBloc>(context);

    if (episode.downloadState == DownloadState.downloading) {
      return IconButton(
        iconSize: 28,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            value: (episode.downloadPercentage ?? 0) / 100,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        style: IconButton.styleFrom(padding: EdgeInsets.zero),
        visualDensity: VisualDensity.compact,
        onPressed: () => _showCancelDialog(context, episodeBloc),
      );
    }

    if (episode.downloadState == DownloadState.queued) {
      return IconButton(
        iconSize: 28,
        icon: const Icon(Icons.timer_outlined),
        style: IconButton.styleFrom(padding: EdgeInsets.zero),
        visualDensity: VisualDensity.compact,
        onPressed: () => _showCancelDialog(context, episodeBloc),
      );
    }

    if (episode.downloaded) {
      return IconButton(
        iconSize: 28,
        icon: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
        style: IconButton.styleFrom(padding: EdgeInsets.zero),
        visualDensity: VisualDensity.compact,
        onPressed: null,
      );
    }

    return IconButton(
      iconSize: 28,
      icon: const Icon(Icons.save_alt),
      style: IconButton.styleFrom(padding: EdgeInsets.zero),
      visualDensity: VisualDensity.compact,
      onPressed: () => podcastBloc.downloadEpisode(episode),
    );
  }

  void _showCancelDialog(BuildContext context, EpisodeBloc episodeBloc) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context)!.stop_download_title),
        content: Text(L.of(context)!.stop_download_confirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L.of(context)!.continue_button_label),
          ),
          TextButton(
            onPressed: () {
              episodeBloc.deleteDownload(episode);
              Navigator.pop(dialogContext);
            },
            child: Text(L.of(context)!.stop_download_button_label),
          ),
        ],
      ),
    );
  }
}

class _PlayerControlState {
  final AudioState audioState;
  final Episode? episode;

  _PlayerControlState(this.audioState, this.episode);
}
