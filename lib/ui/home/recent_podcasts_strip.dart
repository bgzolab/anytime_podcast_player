// Copyright 2026 HX, Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/library/library_page.dart';
import 'package:anytime/ui/podcast/podcast_details.dart';
import 'package:anytime/ui/widgets/podcast_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A horizontal strip of recently-updated subscribed podcast avatars.
/// Tapping a podcast navigates to its detail page. The last item is "See All"
/// which opens the full Library page.
class RecentPodcastsStrip extends StatelessWidget {
  const RecentPodcastsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final podcastBloc = Provider.of<PodcastBloc>(context);

    return StreamBuilder<List<Podcast>>(
      stream: podcastBloc.subscriptions,
      builder: (context, snapshot) {
        final podcasts = snapshot.data ?? [];
        final sorted = List<Podcast>.from(podcasts)..sort((a, b) => b.latestEpisodeDate.compareTo(a.latestEpisodeDate));
        final display = sorted.take(10).toList();

        if (display.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 100,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: display.length + 1,
            itemExtent: 80,
            itemBuilder: (context, index) {
              if (index == display.length) {
                return _SeeAllItem();
              }
              final podcast = display[index];
              return _PodcastStripItem(podcast: podcast);
            },
          ),
        );
      },
    );
  }
}

class _PodcastStripItem extends StatelessWidget {
  final Podcast podcast;

  const _PodcastStripItem({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final bloc = Provider.of<PodcastBloc>(context, listen: false);
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'podcastdetails'),
            builder: (context) => PodcastDetails(podcast, bloc),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 48,
              height: 48,
              child: PodcastImage(
                url: podcast.imageUrl ?? '',
                width: 48,
                height: 48,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            podcast.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SeeAllItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'library'),
            builder: (context) => const LibraryPage(),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(Icons.apps, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            L.of(context)!.see_all,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
