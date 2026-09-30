// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/library/library.dart';
import 'package:anytime/ui/widgets/layout_selector.dart';
import 'package:anytime/ui/widgets/rss_feed_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Full-screen Library page. Pushed as a separate route from the "See All"
/// item in the RecentPodcastsStrip or from other entry points.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = Provider.of<PodcastBloc>(context, listen: false);
        bloc.podcastEvent(PodcastEvent.reloadSubscriptions);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.of(context)!.library),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: L.of(context)!.update_library_option,
            onPressed: () {
              final bloc = Provider.of<PodcastBloc>(context, listen: false);
              bloc.podcastEvent(PodcastEvent.refreshSubscriptions);
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: L.of(context)!.layout_label,
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                  ),
                ),
                builder: (context) => const LayoutSelectorWidget(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.rss_feed),
            tooltip: L.of(context)!.add_rss_feed_option,
            onPressed: () => showRssFeedDialog(context),
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          Library(),
        ],
      ),
    );
  }
}
