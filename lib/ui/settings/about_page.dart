// Copyright 2020 Ben Hills, bGZo(HX) and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/core/environment.dart';
import 'package:anytime/l10n/L.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tileShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title: Text(L.of(context)!.about_label),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/anytime-logo-s.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'Anytime Podcast Player',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  Environment.projectVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, L.of(context)!.about_section_links),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            shape: tileShape,
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.code,
                  title: 'GitHub',
                  subtitle: 'bgzo-sandbox/anytime_podcast_player',
                  url: 'https://github.com/bgzo-sandbox/anytime_podcast_player',
                  tileShape: tileShape,
                ),
                _LinkTile(
                  icon: Icons.send,
                  title: L.of(context)!.about_author_telegram,
                  subtitle: '@imbgzo',
                  url: 'https://t.me/imbgzo',
                  tileShape: tileShape,
                ),
                _LinkTile(
                  icon: Icons.update,
                  title: L.of(context)!.about_check_updates,
                  subtitle: 'GitHub Releases',
                  url: 'https://github.com/bgzo-sandbox/anytime_podcast_player/releases',
                  tileShape: tileShape,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(context, L.of(context)!.about_section_legal),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            shape: tileShape,
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.description_outlined,
                  title: L.of(context)!.about_view_licenses,
                  subtitle: L.of(context)!.about_open_source_licenses,
                  url: '',
                  tileShape: tileShape,
                  isLast: true,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Anytime Podcast Player',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '\u00a9 2026 Ben Hills, bGZo(HX) and the project contributors',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final ShapeBorder? tileShape;
  final bool isLast;
  final VoidCallback? onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    this.tileShape,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        ListTile(
          shape: tileShape,
          leading: Icon(icon, color: colorScheme.onSurfaceVariant),
          title: Text(title),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          onTap: onTap ??
              () async {
                final uri = Uri.parse(url);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  throw Exception('Could not launch $uri');
                }
              },
        ),
        if (!isLast) Divider(height: 1, thickness: 0.5, indent: 56, color: colorScheme.outlineVariant),
      ],
    );
  }
}
