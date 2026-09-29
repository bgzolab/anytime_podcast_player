// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:url_launcher/url_launcher.dart';

/// Strips inline `color` and `line-height` CSS declarations from `style`
/// attributes in [html].
///
/// Some podcast sources (e.g. Ximalaya) embed hard-coded text colours like
/// `color:#333333` and large line-heights like `line-height:30px`, which are
/// unreadable on a dark theme or cause excessive spacing. Removing just those
/// declarations lets flutter_html inherit the app theme; other declarations
/// (e.g. `background-color`) are preserved.
String stripInlineColors(String html) {
  final styleAttribute = RegExp(r'''(\s*)style\s*=\s*(?:"([^"]*)"|'([^']*)')''', caseSensitive: false);

  return html.replaceAllMapped(styleAttribute, (match) {
    final prefix = match.group(1) ?? '';
    final quoted = match.group(2) != null;
    final value = match.group(2) ?? match.group(3) ?? '';
    final kept = value
        .split(';')
        .map((declaration) => declaration.trim())
        .where((declaration) => declaration.isNotEmpty)
        .where((declaration) {
      final property = declaration.split(':').first.trim().toLowerCase();

      return property != 'color' && property != 'line-height';
    }).join('; ');

    // Remove the whole attribute (and its leading whitespace) when nothing is
    // left to apply.
    if (kept.isEmpty) return '';

    final quote = quoted ? '"' : "'";

    return '${prefix}style=$quote$kept$quote';
  });
}

/// This class is a simple, common wrapper around the flutter_html Html widget.
///
/// This wrapper allows us to remove some of the HTML tags which can cause rendering
/// issues when viewing podcast descriptions on a mobile device.
class PodcastHtml extends StatelessWidget {
  final String content;
  final FontSize? fontSize;
  final bool clipboard;

  const PodcastHtml({
    super.key,
    required this.content,
    this.fontSize,
    this.clipboard = true,
  });

  @override
  Widget build(BuildContext context) {
    return clipboard
        ? SelectionArea(
            child: HtmlRenderer(content: content),
          )
        : HtmlRenderer(content: content);
  }
}

class HtmlRenderer extends StatelessWidget {
  const HtmlRenderer({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanedContent = stripInlineColors(content);

    return Html(
      data: cleanedContent,
      extensions: const [
        SvgHtmlExtension(),
        TableHtmlExtension(),
      ],
      style: {
        'html': Style(
          fontSize: FontSize(16.25),
          lineHeight: LineHeight.percent(135),
          color: theme.textTheme.bodyMedium?.color,
          whiteSpace: WhiteSpace.normal,
        ),
        'p': Style(
          margin: Margins.only(
            top: 0,
            bottom: 12,
          ),
        ),
        'body': Style(
          color: theme.textTheme.bodyMedium?.color,
        ),
      },
      onLinkTap: (url, _, __) => canLaunchUrl(Uri.parse(url!)).then((value) => launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          )),
    );
  }
}
