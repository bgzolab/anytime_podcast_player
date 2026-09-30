// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/podcast/podcast_details.dart';
import 'package:anytime/ui/widgets/action_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dialogs/flutter_dialogs.dart';
import 'package:provider/provider.dart';

/// Shows a dialog for adding an RSS feed URL. Extracted from the old menu
/// handler in anytime_podcast_app.dart for reuse across LibraryPage and
/// other entry points.
void showRssFeedDialog(BuildContext context) {
  var textFieldController = TextEditingController();
  var url = '';

  showPlatformDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (_) => BasicDialogAlert(
      title: Text(L.of(context)!.add_rss_feed_option),
      content: Material(
        color: Colors.transparent,
        child: TextField(
          onChanged: (value) {
            url = value;
          },
          controller: textFieldController,
          decoration: const InputDecoration(hintText: 'https://'),
        ),
      ),
      actions: <Widget>[
        BasicDialogAction(
          title: ActionText(L.of(context)!.cancel_button_label),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        BasicDialogAction(
          title: ActionText(L.of(context)!.ok_button_label),
          iosIsDefaultAction: true,
          onPressed: () {
            final podcastBloc = Provider.of<PodcastBloc>(context, listen: false);
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'podcastdetails'),
                builder: (context) => PodcastDetails(Podcast.fromUrl(url: url), podcastBloc),
              ),
            ).then((value) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          },
        ),
      ],
    ),
  );
}
