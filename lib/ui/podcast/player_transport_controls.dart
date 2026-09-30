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

/// Builds a transport control bar for bookmark, play and fast-forward.
/// See [NowPlaying].
class PlayerTransportControls extends StatefulWidget {
  const PlayerTransportControls({
    super.key,
  });

  @override
  State<PlayerTransportControls> createState() => _PlayerTransportControlsState();
}

class _PlayerTransportControlsState extends State<PlayerTransportControls> {
  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: StreamBuilder<AudioState>(
          stream: audioBloc.playingState,
          initialData: AudioState.none,
          builder: (context, snapshot) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                const SleepSelectorWidget(),
                IconButton(
                  onPressed: () {
                    return snapshot.data == AudioState.buffering ? null : _rewind(audioBloc);
                  },
                  padding: const EdgeInsets.all(0.0),
                  icon: Icon(
                    semanticLabel: L.of(context)!.rewind_button_label,
                    Icons.replay_10,
                    size: 48.0,
                  ),
                ),
                AnimatedPlayButton(audioState: snapshot.data!),
                IconButton(
                  onPressed: () {
                    return snapshot.data == AudioState.buffering ? null : _fastforward(audioBloc);
                  },
                  padding: const EdgeInsets.all(0.0),
                  icon: Icon(
                    semanticLabel: L.of(context)!.fast_forward_button_label,
                    Icons.forward_30,
                    size: 48.0,
                  ),
                ),
                BookmarkButton(audioState: snapshot.data!),
                const SpeedSelectorWidget(),
              ],
            );
          }),
    );
  }

  void _rewind(AudioBloc audioBloc) {
    audioBloc.transitionState(TransitionState.rewind);
  }

  void _fastforward(AudioBloc audioBloc) {
    audioBloc.transitionState(TransitionState.fastforward);
  }
}

/// A bookmark button that creates a bookmark at the current playback position.
class BookmarkButton extends StatefulWidget {
  final AudioState audioState;

  const BookmarkButton({
    super.key,
    required this.audioState,
  });

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> with SingleTickerProviderStateMixin {
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

    final positionState = audioBloc.playPosition?.valueOrNull;
    final episode = audioBloc.nowPlaying?.valueOrNull;

    if (positionState == null || episode == null) return;

    final positionMs = positionState.position.inMilliseconds;

    bookmarkBloc.event(BookmarkCreateEvent(
      episode: episode,
      positionMs: positionMs,
    ));

    // Play sound effect
    BookmarkSound.play();

    // Show SnackBar feedback
    final timestamp = _formatDuration(positionState.position);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.of(context)!.bookmark_added_snackbar(timestamp)),
        duration: const Duration(seconds: 2),
      ),
    );

    // Animate icon
    setState(() => _justBookmarked = true);
    _animController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() => _justBookmarked = false);
            }
          });
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    var twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).toInt());
    var twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).toInt());

    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.audioState == AudioState.playing || widget.audioState == AudioState.pausing;
    final isBuffering = widget.audioState == AudioState.buffering;

    return Tooltip(
      message: L.of(context)!.bookmark_add_button_label,
      child: IconButton(
        onPressed: isBuffering
            ? null
            : isPlaying
                ? _createBookmark
                : null,
        padding: const EdgeInsets.all(0.0),
        icon: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.3).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
          ),
          child: Icon(
            semanticLabel: L.of(context)!.bookmark_add_button_label,
            _justBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
            size: 36.0,
            color: _justBookmarked ? Theme.of(context).colorScheme.primary : null,
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

void _onPlay(AudioBloc audioBloc) {
  audioBloc.transitionState(TransitionState.play);
}

void _onPause(AudioBloc audioBloc) {
  audioBloc.transitionState(TransitionState.pause);
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  late StreamSubscription<AudioState> _audioStateSubscription;
  bool init = true;

  @override
  void initState() {
    super.initState();

    final audioBloc = Provider.of<AudioBloc>(context, listen: false);

    _playPauseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    /// Seems a little hacky, but when we load the form we want the play/pause
    /// button to be in the correct state. If we are building the first frame,
    /// just set the animation controller to the correct state; for all other
    /// frames we want to animate. Doing it this way prevents the play/pause
    /// button from animating when the form is first loaded.
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
      alignment: AlignmentDirectional.center,
      children: [
        if (buffering)
          SpinKitRing(
            lineWidth: 4.0,
            color: colorScheme.primary,
            size: 84,
          ),
        if (!buffering)
          const SizedBox(
            height: 84,
            width: 84,
          ),
        Tooltip(
          message: playing ? L.of(context)!.pause_button_label : L.of(context)!.play_button_label,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: CircleBorder(side: BorderSide(color: colorScheme.surface, width: 0.0)),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.all(6.0),
            ),
            onPressed: () {
              if (playing) {
                widget.onPause(audioBloc);
              } else {
                widget.onPlay(audioBloc);
              }
            },
            child: AnimatedIcon(
              size: 60.0,
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
