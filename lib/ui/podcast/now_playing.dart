// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/chapter.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/feed.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/podcast/bookmark_view.dart';
import 'package:anytime/ui/podcast/chapter_selector.dart';
import 'package:anytime/ui/podcast/now_playing_options.dart';
import 'package:anytime/ui/podcast/podcast_details.dart';
import 'package:anytime/ui/podcast/transcript_view.dart';
import 'package:anytime/ui/podcast/person_avatar.dart';
import 'package:anytime/ui/podcast/playback_error_listener.dart';
import 'package:anytime/ui/podcast/player_position_controls.dart';
import 'package:anytime/ui/podcast/player_transport_controls.dart';
import 'package:anytime/ui/widgets/delayed_progress_indicator.dart';
import 'package:anytime/ui/widgets/placeholder_builder.dart';
import 'package:anytime/ui/widgets/podcast_html.dart';
import 'package:anytime/ui/widgets/podcast_image.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen player widget invoked by tapping the mini player.
class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> with WidgetsBindingObserver {
  late StreamSubscription<AudioState> playingStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    var popped = false;

    playingStateSubscription =
        audioBloc.playingState!.where((state) => state == AudioState.stopped).listen((_) async {
      if (!popped) {
        popped = true;
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    playingStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final playerBuilder = PlayerControlsBuilder.of(context);

    return Semantics(
      header: false,
      label: L.of(context)!.semantics_main_player_header,
      explicitChildNodes: true,
      child: StreamBuilder<Episode?>(
        stream: audioBloc.nowPlaying,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Container();
          var duration = snapshot.data == null ? 0 : snapshot.data!.duration;
          final WidgetBuilder? transportBuilder = playerBuilder?.builder(duration);
          return NowPlayingLayout(episode: snapshot.data!, transportBuilder: transportBuilder);
        },
      ),
    );
  }
}

/// Main layout: AppBar with TabBar, episode details, transport controls, options panel.
class NowPlayingLayout extends StatefulWidget {
  final Episode episode;
  final WidgetBuilder? transportBuilder;

  const NowPlayingLayout({super.key, required this.episode, this.transportBuilder});

  @override
  State<NowPlayingLayout> createState() => _NowPlayingLayoutState();
}

class _NowPlayingLayoutState extends State<NowPlayingLayout> with TickerProviderStateMixin {
  late TabController tabController;
  bool startedWithChapters = false;

  @override
  void initState() {
    super.initState();
    startedWithChapters = widget.episode.hasChapters;
    tabController = TabController(
      length: widget.episode.hasChapters ? 5 : 4,
      initialIndex: widget.episode.hasChapters ? 1 : 0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(NowPlayingLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.episode.hasChapters != startedWithChapters) {
      final currentIndex = tabController.index;
      final oldController = tabController;
      setState(() {
        tabController = TabController(
          length: widget.episode.hasChapters ? 5 : 4,
          initialIndex: currentIndex + 2,
          vsync: this,
        );
        startedWithChapters = widget.episode.hasChapters;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => oldController.dispose());
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colorScheme.surface,
        systemNavigationBarIconBrightness:
            theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: L.of(context)!.minimise_player_window_button_label,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: theme.primaryIconTheme.color,
              semanticLabel: L.of(context)!.minimise_player_window_button_label,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: PlaybackErrorListener(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                EpisodeTabBar(
                  controller: tabController,
                  chapters: widget.episode.hasChapters,
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
              // 1 Episode details (artwork, chapters, show notes, bookmarks, transcript)
              //   Uses Expanded so it takes all remaining space above controls + options.
              Expanded(
                child: EpisodeTabBarView(
                  controller: tabController,
                  episode: widget.episode,
                  chapters: widget.episode.hasChapters,
                ),
              ),
              // 2 Transport controls: wavy progress bar + play/pause/skip/bookmark/buttons
              SizedBox(
                height: 124,
                child: widget.transportBuilder != null
                    ? widget.transportBuilder!(context)
                    : const NowPlayingTransport(),
              ),
              // 3 Options panel: collapsible Up Next queue at the very bottom.
              //   Tap the handle or drag up/down to expand/collapse.
              const NowPlayingOptionsSelector(),
          ],
        ),
      ),
    );
  }
}

/// Transport controls wrapper.
class NowPlayingTransport extends StatelessWidget {
  const NowPlayingTransport({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerPositionControls(),
        PlayerTransportControls(),
      ],
    );
  }
}

/// Tab bar for episode detail sections.
class EpisodeTabBar extends StatefulWidget {
  final bool chapters;
  final TabController controller;
  const EpisodeTabBar({super.key, required this.controller, this.chapters = false});

  @override
  State<EpisodeTabBar> createState() => _EpisodeTabBarState();
}

class _EpisodeTabBarState extends State<EpisodeTabBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const double colimnWidth = 75;
    return TabBar(
      controller: widget.controller,
      isScrollable: true,
      labelStyle: theme.textTheme.titleSmall,
      unselectedLabelStyle: theme.textTheme.titleSmall,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.onPrimaryContainer,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      tabs: [
        if (widget.chapters)
          Tab(child: SizedBox(width: colimnWidth, child: Align(alignment: Alignment.center, child: Text(L.of(context)!.chapters_label)))),
        Tab(child: SizedBox(width: colimnWidth, child: Align(alignment: Alignment.center, child: Text(L.of(context)!.episode_label)))),
        Tab(child: SizedBox(width: colimnWidth, child: Align(alignment: Alignment.center, child: Text(L.of(context)!.show_notes_label)))),
        Tab(child: SizedBox(width: colimnWidth, child: Align(alignment: Alignment.center, child: Text(L.of(context)!.bookmarks_label)))),
        Tab(child: SizedBox(width: colimnWidth, child: Align(alignment: Alignment.center, child: Text(L.of(context)!.transcript_label)))),
      ],
    );
  }
}

/// Tab body views.
class EpisodeTabBarView extends StatelessWidget {
  final Episode? episode;
  final bool chapters;
  final TabController controller;
  const EpisodeTabBarView({super.key, required this.controller, this.episode, this.chapters = false});

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context);
    return TabBarView(
      controller: controller,
      children: [
        if (chapters) ChapterSelector(episode: episode!),
        StreamBuilder<Episode?>(
          key: const PageStorageKey('episodestream'),
          stream: audioBloc.nowPlaying,
          builder: (context, snapshot) {
            final e = snapshot.hasData ? snapshot.data! : episode!;
            return NowPlayingEpisode(episode: e);
          },
        ),
        NowPlayingShowNotes(key: const PageStorageKey('episodenotes'), episode: episode),
        const BookmarkView(),
        const TranscriptView(),
      ],
    );
  }
}

/// Episode tab: artwork + title + podcast name + details.
class NowPlayingEpisode extends StatelessWidget {
  final Episode episode;
  const NowPlayingEpisode({super.key, required this.episode});

  void _openPodcastDetails(BuildContext context) async {
    final podcastBloc = Provider.of<PodcastBloc>(context, listen: false);
    final subscriptions = await podcastBloc.subscriptions.first;

    Podcast? match;
    if (episode.pguid != null) {
      match = subscriptions.where((p) => p.guid == episode.pguid).firstOrNull;
    }
    match ??= subscriptions.where((p) => p.title == episode.podcast).firstOrNull;

    if (match == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podcast not found in your library. Subscribe first.')),
        );
      }
      return;
    }
    final podcast = match;
    podcastBloc.load(Feed(podcast: podcast, backgroundFetch: true, errorSilently: true));
    if (context.mounted) {
      Navigator.push(context,
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'podcastdetails'),
            builder: (context) => PodcastDetails(podcast, podcastBloc),
          ));
    }
  }

  Widget _buildChapterSection(BuildContext context, Chapter? ch) {
    if (ch == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ch.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(ch.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        if ((ch.url?.isNotEmpty ?? false))
          IconButton(
            icon: const Icon(Icons.link, size: 18),
            onPressed: () async {
              final uri = Uri.parse(ch.url!);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final placeholderBuilder = PlaceholderBuilder.of(context);
    final size = MediaQuery.sizeOf(context);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            flex: 7,
            child: Semantics(
              label: L.of(context)!.semantic_podcast_artwork_label,
              child: PodcastImage(
                key: Key('nowplaying${episode.positionalImageUrl}'),
                url: episode.positionalImageUrl ?? episode.imageUrl ?? '',
                width: size.width * 0.75,
                height: size.height * 0.75,
                fit: BoxFit.contain,
                borderRadius: 6,
                placeholder: placeholderBuilder != null
                    ? placeholderBuilder.builder()(context)
                    : DelayedCircularProgressIndicator(),
                errorPlaceholder: placeholderBuilder != null
                    ? placeholderBuilder.errorBuilder()(context)
                    : const Image(image: AssetImage('assets/images/anytime-placeholder-logo.png')),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AutoSizeText(
                  episode.title ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _openPodcastDetails(context),
                  child: Text(
                    episode.podcast ?? '',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                if (episode.hasChapters) _buildChapterSection(context, episode.currentChapter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show notes with persons and HTML content.
class NowPlayingShowNotes extends StatelessWidget {
  final Episode? episode;
  const NowPlayingShowNotes({super.key, required this.episode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(episode!.title!, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (episode!.persons.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: episode!.persons.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) => PersonAvatar(person: episode!.persons[index]),
              ),
            ),
          const SizedBox(height: 8),
          PodcastHtml(content: episode?.content ?? episode?.description ?? ''),
        ],
      ),
    );
  }
}

/// Allows users to inject custom transport controls via InheritedWidget.
class PlayerControlsBuilder extends InheritedWidget {
  final WidgetBuilder Function(int duration) builder;
  const PlayerControlsBuilder({super.key, required this.builder, required super.child});

  static PlayerControlsBuilder? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PlayerControlsBuilder>();
  }

  @override
  bool updateShouldNotify(PlayerControlsBuilder oldWidget) => builder != oldWidget.builder;
}
