// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/bookmark/bookmark_bloc.dart';
import 'package:anytime/bloc/podcast/episode_bloc.dart';
import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/state/bloc_state.dart';
import 'package:anytime/ui/my/bookmarks_page_full.dart';
import 'package:anytime/ui/my/downloads_page.dart';
import 'package:anytime/ui/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// My page hub — tab 2 of the bottom navigation. Contains navigation items
/// for Downloads, Bookmarks, Settings, About, and placeholders.
class MyPage extends StatefulWidget {
  final Repository? repository;

  const MyPage({super.key, this.repository});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<EpisodeBloc>(context, listen: false).fetchDownloads(false);
        Provider.of<BookmarkBloc>(context, listen: false).event(BookmarkFetchAllEvent());
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        L.of(context)!.my_tab,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episodeBloc = Provider.of<EpisodeBloc>(context, listen: false);
    final bookmarkBloc = Provider.of<BookmarkBloc>(context, listen: false);

    return ListView(
      children: [
        _buildHeader(context),
        _buildSectionHeader(context, 'Library'),
        _MenuTile(
          icon: Icons.download_outlined,
          title: L.of(context)!.downloads,
          trailing: StreamBuilder<BlocState<List<Episode>>>(
            stream: episodeBloc.downloads,
            builder: (context, snapshot) {
              final state = snapshot.data;
              int count = 0;
              if (state is BlocPopulatedState<List<Episode>>) {
                count = state.results?.length ?? 0;
              }
              return Text('$count', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary));
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => DownloadsPage(repository: widget.repository),
              ),
            );
          },
        ),
        _MenuTile(
          icon: Icons.bookmark_outline,
          title: L.of(context)!.bookmarks_label,
          trailing: StreamBuilder<BlocState>(
            stream: bookmarkBloc.state,
            builder: (context, snapshot) {
              final state = snapshot.data;
              int count = 0;
              if (state is BlocPopulatedState<List<Bookmark>>) {
                count = state.results?.length ?? 0;
              }
              return Text('$count', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary));
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => BookmarksPageFull(repository: widget.repository),
              ),
            );
          },
        ),
        const Divider(indent: 16, endIndent: 16),
        _buildSectionHeader(context, 'App'),
        _MenuTile(
          icon: Icons.settings_outlined,
          title: L.of(context)!.settings_label,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                settings: const RouteSettings(name: 'settings'),
                builder: (context) => const Settings(),
              ),
            );
          },
        ),
        _MenuTile(
          icon: Icons.info_outline,
          title: L.of(context)!.about_label,
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Anytime Podcast Player',
              applicationIcon: Image.asset(
                'assets/images/anytime-logo-s.png',
                width: 52.0,
                height: 52.0,
              ),
              children: [
                Text('\u00a9 2020 Ben Hills'),
              ],
            );
          },
        ),
        const Divider(indent: 16, endIndent: 16),
        _buildSectionHeader(context, 'More'),
        _MenuTile(
          icon: Icons.bar_chart_outlined,
          title: 'Listening Stats',
          enabled: false,
        ),
        _MenuTile(
          icon: Icons.tune_outlined,
          title: 'Customize',
          enabled: false,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.38)),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: enabled ? null : theme.colorScheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
      trailing: trailing ?? (enabled
          ? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant)
          : Text(L.of(context)!.coming_soon,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              ))),
      onTap: enabled ? onTap : null,
    );
  }
}
