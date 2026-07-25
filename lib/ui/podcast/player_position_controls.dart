// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Position controls with animated wavy progress bar and time labels.
class PlayerPositionControls extends StatefulWidget {
  const PlayerPositionControls({super.key});

  @override
  State<PlayerPositionControls> createState() => _PlayerPositionControlsState();
}

class _PlayerPositionControlsState extends State<PlayerPositionControls>
    with SingleTickerProviderStateMixin {
  var dragging = false;
  int currentPosition = 0;
  int episodeLength = 0;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _toggleWave(AudioState state) {
    if (state == AudioState.playing || state == AudioState.buffering) {
      if (!_waveController.isAnimating) _waveController.repeat();
    } else {
      if (_waveController.isAnimating) _waveController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final audioBloc = Provider.of<AudioBloc>(context);

    return StreamBuilder<AudioState>(
      stream: audioBloc.playingState,
      builder: (context, stateSnapshot) {
        _toggleWave(stateSnapshot.data ?? AudioState.stopped);

        return StreamBuilder<PositionState>(
          stream: audioBloc.playPosition,
          builder: (context, snapshot) {
            var pos = snapshot.hasData ? snapshot.data!.position.inSeconds : 0;
            episodeLength = snapshot.hasData ? snapshot.data!.length.inSeconds : 0;
            if (!dragging) currentPosition = pos.clamp(0, episodeLength);
            final progress = episodeLength > 0 ? currentPosition / episodeLength : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      return GestureDetector(
                        onTapDown: (d) => _seek(w, d.localPosition.dx, audioBloc),
                        onHorizontalDragUpdate: (d) {
                          setState(() => dragging = true);
                          if (w > 0 && episodeLength > 0) {
                            currentPosition = (d.localPosition.dx / w * episodeLength).round().clamp(0, episodeLength);
                          }
                        },
                        onHorizontalDragEnd: (_) {
                          setState(() => dragging = false);
                          if (episodeLength > 0) audioBloc.transitionPosition(currentPosition.toDouble());
                        },
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) {
                            final animating = _waveController.isAnimating;
                            return CustomPaint(
                              size: Size(w, 24),
                              painter: _WavyPainter(
                                progress: progress,
                                phase: animating ? _waveController.value * 2 * math.pi : 0,
                                animating: animating,
                                color: colorScheme.primary,
                                bgColor: colorScheme.surfaceContainerHighest,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(Duration(seconds: currentPosition)),
                          style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(_fmt(Duration(seconds: episodeLength - currentPosition)),
                          style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _seek(double w, double dx, AudioBloc bloc) {
    if (w > 0 && episodeLength > 0) {
      bloc.transitionPosition((dx / w * episodeLength).round().clamp(0, episodeLength).toDouble());
    }
  }

  String _fmt(Duration d) {
    final m = (d.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
  }
}

class _WavyPainter extends CustomPainter {
  final double progress;
  final double phase;
  final bool animating;
  final Color color;
  final Color bgColor;

  _WavyPainter({
    required this.progress,
    required this.phase,
    required this.animating,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 2;
    final w = size.width;
    final amp = animating ? 5.0 : 0.0;
    const waveLen = 22.0;
    const stroke = 3.0;

    final bg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final split = w * progress;

    // Background wave
    final bgPath = Path();
    for (double x = 0; x <= w; x += 1) {
      final y = h + math.sin((x / waveLen) * 2 * math.pi + phase) * amp;
      (x == 0 ? bgPath.moveTo : bgPath.lineTo)(x, y);
    }
    canvas.drawPath(bgPath, bg);

    // Foreground wave
    if (progress > 0.01) {
      final fgPath = Path();
      for (double x = 0; x <= split; x += 1) {
        final y = h + math.sin((x / waveLen) * 2 * math.pi + phase) * amp;
        (x == 0 ? fgPath.moveTo : fgPath.lineTo)(x, y);
      }
      canvas.drawPath(fgPath, fg);
    }

    // Dot
    if (progress > 0 && progress < 1) {
      final dotY = h + math.sin((split / waveLen) * 2 * math.pi + phase) * amp;
      canvas.drawCircle(Offset(split, dotY), stroke * 1.5, Paint()..color = color..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_WavyPainter o) =>
      o.progress != progress || o.phase != phase || o.animating != animating;
}
