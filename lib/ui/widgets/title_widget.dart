// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class TitleWidget extends StatelessWidget {
  const TitleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.bold,
      fontFamily: 'MontserratRegular',
      fontSize: 18,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 2.0),
      child: Row(
        children: <Widget>[
          Text(
            'Anytime ',
            style: titleStyle.copyWith(color: colorScheme.primary),
          ),
          Text(
            'Player',
            style: titleStyle.copyWith(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
