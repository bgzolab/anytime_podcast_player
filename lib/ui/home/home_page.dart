// Copyright 2026 HX, Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/timeline/timeline_bloc.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/home/recent_podcasts_strip.dart';
import 'package:anytime/ui/library/timeline.dart';
import 'package:anytime/ui/podcast/up_next_view.dart';
import 'package:anytime/ui/search/search.dart';
import 'package:anytime/ui/search/search_mode.dart';
import 'package:anytime/ui/widgets/search_slide_route.dart';
import 'package:anytime/ui/widgets/title_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  late StreamSubscription _blocSubscription;
  bool _showPlayed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final bloc = Provider.of<TimelineBloc>(context, listen: false);
    _showPlayed = bloc.showPlayed;
    final blocRef = bloc;
    _blocSubscription = bloc.state.listen((_) {
      final current = blocRef.showPlayed;
      if (current != _showPlayed) {
        setState(() => _showPlayed = current);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _blocSubscription.cancel();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColour = Theme.of(context).scaffoldBackgroundColor;
    final colorScheme = Theme.of(context).colorScheme;
    final bloc = Provider.of<TimelineBloc>(context, listen: false);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarColor = isDark ? const Color(0xFF1C1B1F) : const Color(0xFFFFFBFE);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Column(
        children: [
          Container(
            height: statusBarHeight,
            color: statusBarColor,
          ),
          Expanded(
            child: Stack(
              children: [
                MediaQuery.removePadding(
                  removeTop: true,
                  context: context,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await bloc.refreshAndWait();
                    },
                    child: Container(
                      color: backgroundColour,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverAppBar(
                            title: const TitleWidget(),
                            backgroundColor: backgroundColour,
                            floating: false,
                            pinned: true,
                            snap: false,
                            surfaceTintColor: Colors.transparent,
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: L.of(context)!.search_episodes_tooltip,
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    defaultTargetPlatform == TargetPlatform.iOS
                                        ? MaterialPageRoute<void>(
                                            fullscreenDialog: false,
                                            settings: const RouteSettings(name: 'search'),
                                            builder: (context) => const Search(mode: SearchMode.home, repository: null))
                                        : SlideRightRoute(
                                            widget: const Search(mode: SearchMode.home, repository: null),
                                            settings: const RouteSettings(name: 'search'),
                                          ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.featured_play_list_outlined),
                                tooltip: L.of(context)!.open_up_next_hint,
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: false,
                                      settings: const RouteSettings(name: 'queue'),
                                      builder: (context) => const UpNextPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: 92,
                              child: RecentPodcastsStrip(),
                            ),
                          ),
                          const Timeline(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        opacity: _showScrollToTop ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: FloatingActionButton.small(
                          heroTag: 'home_scroll_to_top',
                          onPressed: () {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: const Icon(Icons.arrow_upward),
                        ),
                      ),
                      if (_showScrollToTop) const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'home_refresh',
                        onPressed: () => bloc.event(TimelineEvent.refresh),
                        backgroundColor: colorScheme.secondaryContainer,
                        child: Icon(Icons.refresh, color: colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'home_toggle_played',
                        onPressed: () => bloc.event(TimelineEvent.toggleShowPlayed),
                        backgroundColor: colorScheme.tertiaryContainer,
                        child: Icon(
                          _showPlayed ? Icons.visibility : Icons.visibility_off,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'home_date_filter',
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: bloc.dateFilter ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null && context.mounted) {
                            bloc.jumpToDate(date);
                          }
                        },
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
