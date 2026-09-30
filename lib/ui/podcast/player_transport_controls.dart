// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/core/bookmark_sound.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/widgets/sleep_selector.dart';
import 'package:anytime/ui/widgets/speed_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

/// Transport controls: Sleep | Like | Rewind10 | Play/Pause | Forward30 | Bookmark | Speed.
class PlayerTransportControls extends StatefulWidget {
  const PlayerTransportControls({super.key});

  @override
  State<PlayerTransportControls> createState() => _PlayerTransportControlsState();
}

class _PlayerTransportControlsState extends State<PlayerTransportControls> {
  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);

    return StreamBuilder<AudioState>(
      stream: audioBloc.playingState,
      initialData: AudioState.none,
      builder: (context, snapshot) {
        final state = snapshot.data ?? AudioState.none;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SleepSelectorWidget(),
            const _LikeButton(),
            IconButton(
              icon: const Icon(Icons.replay_10, size: 28),
              tooltip: L.of(context)!.rewind_button_label,
              onPressed: () => audioBloc.transitionState(TransitionState.rewind),
            ),
            AnimatedPlayButton(audioState: state),
            IconButton(
              icon: const Icon(Icons.forward_30, size: 28),
              tooltip: L.of(context)!.fast_forward_button_label,
              onPressed: () => audioBloc.transitionState(TransitionState.fastforward),
            ),
            const _BookmarkButton(),
            const SpeedSelectorWidget(),
          ],
        );
      },
    );
  }
}

/// Placeholder like/favorite button (no logic yet).
class _LikeButton extends StatelessWidget {
  const _LikeButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.favorite_border, size: 28),
      tooltip: L.of(context)!.like_tooltip,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context)!.like_coming_soon), duration: const Duration(seconds: 1)),
        );
      },
    );
  }
}

/// Bookmark button that creates a bookmark at the current playback position.
class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton();

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _justBookmarked = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _createBookmark() {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);
    final positionState = audioBloc.playPosition?.value;
    final episode = audioBloc.nowPlaying?.value;
    if (positionState == null || episode == null) return;

    bookmarkBloc.event(BookmarkCreateEvent(
      episode: episode,
      positionMs: positionState.position.inMilliseconds,
    ));
    BookmarkSound.play();

    final timestamp = _formatDuration(positionState.position);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.of(context)!.bookmark_added_snackbar(timestamp)),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() => _justBookmarked = true);
    _animController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) setState(() => _justBookmarked = false);
          });
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n >= 10 ? '$n' : '0$n';
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: L.of(context)!.bookmark_add_button_label,
      child: IconButton(
        onPressed: _createBookmark,
        icon: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.3).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
          ),
          child: Icon(
            _justBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
            size: 28,
            color: _justBookmarked ? colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

typedef PlayHandler = Function(AudioBloc audioBloc);

class AnimatedPlayButton extends StatefulWidget {
  final AudioState audioState;
  final PlayHandler onPlay;
  final PlayHandler onPause;

  const AnimatedPlayButton({
    super.key,
    required this.audioState,
    this.onPlay = _onPlay,
    this.onPause = _onPause,
  });

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

void _onPlay(AudioBloc audioBloc) => audioBloc.transitionState(TransitionState.play);
void _onPause(AudioBloc audioBloc) => audioBloc.transitionState(TransitionState.pause);

class _AnimatedPlayButtonState extends State<AnimatedPlayButton> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  late StreamSubscription<AudioState> _audioStateSubscription;
  bool init = true;

  @override
  void initState() {
    super.initState();
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    _playPauseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _audioStateSubscription = audioBloc.playingState!.listen((event) {
      if (event == AudioState.playing || event == AudioState.buffering) {
        if (init) {
          _playPauseController.value = 1;
          init = false;
        } else {
          _playPauseController.forward();
        }
      } else {
        if (init) {
          _playPauseController.value = 0;
          init = false;
        } else {
          _playPauseController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    _audioStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final playing = widget.audioState == AudioState.playing;
    final buffering = widget.audioState == AudioState.buffering;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (buffering) SpinKitRing(lineWidth: 4.0, color: colorScheme.primary, size: 64),
        if (!buffering) const SizedBox(height: 64, width: 64),
        Tooltip(
          message: playing ? L.of(context)!.pause_button_label : L.of(context)!.play_button_label,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: CircleBorder(side: BorderSide(color: colorScheme.surface, width: 0)),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.all(4),
            ),
            onPressed: () {
              if (playing) {
                widget.onPause(audioBloc);
              } else {
                widget.onPlay(audioBloc);
              }
            },
            child: AnimatedIcon(
              size: 44,
              semanticLabel: playing ? L.of(context)!.pause_button_label : L.of(context)!.play_button_label,
              icon: AnimatedIcons.play_pause,
              color: colorScheme.onPrimary,
              progress: _playPauseController,
            ),
          ),
        ),
      ],
    );
  }
}
