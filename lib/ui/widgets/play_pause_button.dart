// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/percent_indicator.dart';

class PlayPauseButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;

  const PlayPauseButton({
    super.key,
    required this.icon,
    required this.label,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$label $title',
      child: CircularPercentIndicator(
        radius: 19.0,
        lineWidth: 1.5,
        backgroundColor: primary,
        percent: 0.0,
        center: Icon(
          icon,
          size: 22.0,
          color: primary,
        ),
      ),
    );
  }
}

class PlayPauseBusyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;

  const PlayPauseBusyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
        label: '$label $title',
        child: Stack(
          children: <Widget>[
            SizedBox(
              height: 48.0,
              width: 48.0,
              child: Icon(
                icon,
                size: 22.0,
                color: primary,
              ),
            ),
            SpinKitRing(
              lineWidth: 1.5,
              color: primary,
              size: 38.0,
            ),
          ],
        ));
  }
}
