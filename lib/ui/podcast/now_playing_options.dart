// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/podcast/up_next_view.dart';
import 'package:flutter/material.dart';

class NowPlayingOptionsSelector extends StatefulWidget {
  final double? scrollPos;
  static const baseSize = 48.0;

  const NowPlayingOptionsSelector({super.key, this.scrollPos});

  @override
  State<NowPlayingOptionsSelector> createState() => _NowPlayingOptionsSelectorState();
}

class _NowPlayingOptionsSelectorState extends State<NowPlayingOptionsSelector> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _toggle,
      onVerticalDragEnd: (details) {
        final dy = details.primaryVelocity ?? 0;
        if (dy < -300 && !_expanded) {
          _toggle();
        } else if (dy > 300 && _expanded) {
          _toggle();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _expanded ? 300 : 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L.of(context)!.up_next_queue_label.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.expand_less,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (_expanded)
              const Expanded(
                child: UpNextView(),
              ),
          ],
        ),
      ),
    );
  }
}

class NowPlayingOptionsScaffold extends StatelessWidget {
  const NowPlayingOptionsScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: NowPlayingOptionsSelector.baseSize);
  }
}

class NowPlayingOptionsSelectorWide extends StatefulWidget {
  final double? scrollPos;
  static const baseSize = 48.0;

  const NowPlayingOptionsSelectorWide({super.key, this.scrollPos});

  @override
  State<NowPlayingOptionsSelectorWide> createState() => _NowPlayingOptionsSelectorWideState();
}

class _NowPlayingOptionsSelectorWideState extends State<NowPlayingOptionsSelectorWide> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                L.of(context)!.up_next_queue_label.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ),
          const Divider(height: 1),
          const Expanded(child: UpNextView()),
        ],
      ),
    );
  }
}
