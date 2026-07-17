// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:logging/logging.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:url_launcher/url_launcher.dart';

/// Strips inline `color` and `line-height` CSS declarations from `style` attributes in HTML content.
///
/// Some podcast sources (e.g. Ximalaya) embed hardcoded text colors like `color:#333333`
/// and large line-heights like `line-height:30px` which look fine on light backgrounds
/// but are unreadable in dark theme or cause excessive spacing. Removing them lets
/// flutter_html inherit the app's theme styling instead.
String stripInlineColors(String html) {
  return html.replaceAllMapped(
    RegExp(r'style="([^"]*)"', caseSensitive: false),
    (match) {
      final value = match.group(1)!;
      // Remove any color:...; or line-height:...; declaration from inline styles
      final cleaned = value
          .replaceAll(RegExp(r'color\s*:\s*[^;]+;?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'line-height\s*:\s*[^;]+;?\s*', caseSensitive: false), '');
      return 'style="$cleaned"';
    },
  );
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
  static final log = Logger('PodcastHtml');
  const HtmlRenderer({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanedContent = stripInlineColors(content);
    // log.info('--- PodcastHtml content (first 2000 chars) ---\n${cleanedContent.length > 2000 ? cleanedContent.substring(0, 2000) : cleanedContent}\n--- END ---');

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
