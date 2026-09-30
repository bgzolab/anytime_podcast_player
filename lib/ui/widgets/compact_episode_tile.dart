// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/bloc/podcast/episode_bloc.dart';
import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/bloc/podcast/queue_bloc.dart';
import 'package:anytime/bloc/settings/settings_bloc.dart';
import 'package:anytime/bloc/timeline/timeline_bloc.dart';
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

/// A compact episode tile with a spacious layout and borderless action buttons.
///
/// Supports swipe actions: left swipe → add to queue, right swipe → ignore.
/// Shows a play/pause overlay on the image only for the currently playing episode.
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
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final settings = Provider.of<SettingsBloc>(context, listen: false).currentSettings;
    final episodeBloc = Provider.of<EpisodeBloc>(context);
    final queueBloc = Provider.of<QueueBloc>(context);

    final playedMuted = episode.played;
    final mutedTextColor = playedMuted ? colorScheme.onSurface.withValues(alpha: 0.6) : null;

    return Dismissible(
      key: ValueKey('episode_${episode.guid}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          queueBloc.queueEvent(QueueAddEvent(episode: episode));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(L.of(context)!.queue_add_label),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          if (context.mounted) {
            Provider.of<TimelineBloc>(context, listen: false).hideEpisode(episode.guid);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(L.of(context)!.episode_hidden),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          Provider.of<TimelineBloc>(context, listen: false).reapplyFilter();
        }
      },
      background: Container(
        color: colorScheme.tertiaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(Icons.visibility_off, color: colorScheme.onTertiaryContainer),
      ),
      secondaryBackground: Container(
        color: colorScheme.primaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.playlist_add, color: colorScheme.onPrimaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Thumbnail with play/pause overlay and progress bar
                _buildImageWithOverlay(context, audioBloc, playedMuted, settings),
                const SizedBox(width: 16.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => EpisodeDetails(episode: episode),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          episode.title!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(color: mutedTextColor),
                        ),
                        if (showPodcastName) ...<Widget>{
                          const SizedBox(height: 2.0),
                          Text(
                            episode.podcast ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        },
                        const SizedBox(height: 2.0),
                        EpisodeSubtitle(episode),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: <Widget>[
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
                      onPressed: () {
                        final timelineBloc = Provider.of<TimelineBloc>(context, listen: false);
                        episodeBloc.togglePlayed(episode);
                        Future.microtask(() => timelineBloc.reapplyFilter());
                      },
                    ),
                  ),
                  Semantics(
                    container: true,
                    child: IconButton(
                      iconSize: 28,
                      icon: const Icon(Icons.visibility_off_outlined),
                      tooltip: L.of(context)!.episode_hidden,
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final bloc = Provider.of<TimelineBloc>(context, listen: false);
                        bloc.hideEpisode(episode.guid);
                        bloc.reapplyFilter();
                      },
                    ),
                  ),
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
      ),
    );
  }

  Widget _buildImageWithOverlay(BuildContext context, AudioBloc audioBloc, bool playedMuted, AppSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<Episode?>(
      stream: audioBloc.nowPlaying,
      initialData: audioBloc.nowPlaying?.valueOrNull,
      builder: (context, snapshot) {
        final nowPlaying = snapshot.data;
        final isCurrentEpisode = nowPlaying?.guid == episode.guid;

        return StreamBuilder<AudioState>(
          stream: audioBloc.playingState!,
          initialData: audioBloc.audioPlayerService.nowPlaying != null ? AudioState.pausing : AudioState.stopped,
          builder: (context, stateSnapshot) {
            final audioState = stateSnapshot.data ?? AudioState.stopped;
            final isPlaying = audioState == AudioState.playing || audioState == AudioState.buffering;

            return GestureDetector(
              onTap: () {
                if (isCurrentEpisode) {
                  if (isPlaying) {
                    audioBloc.transitionState(TransitionState.pause);
                  } else {
                    audioBloc.transitionState(TransitionState.play);
                  }
                } else {
                  audioBloc.play(episode);
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
              },
              child: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: <Widget>[
                    Opacity(
                      opacity: playedMuted ? 0.5 : 1.0,
                      child: TileImage(
                        url: episode.thumbImageUrl ?? episode.imageUrl!,
                        size: 80.0,
                        highlight: episode.highlight,
                      ),
                    ),
                    SizedBox(
                      height: 5.0,
                      width: 80.0 * (episode.percentagePlayed / 100),
                      child: Container(color: colorScheme.primary),
                    ),
                    if (isCurrentEpisode)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
