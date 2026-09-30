// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:url_launcher/url_launcher.dart';

/// Matches a single HTML tag, including its attributes.
///
/// Scoping the replacements to tags (as opposed to scanning the whole
/// document) keeps text, `<script>` strings and `<style>` selectors that
/// happen to contain `style="…"` untouched.
final _htmlTag = RegExp(r'<[a-zA-Z][^>]*>');

/// Matches a quoted style attribute together with its leading whitespace.
///
/// Requiring whitespace before `style` keeps attributes such as
/// `data-style="…"` from matching.
final _styleAttribute = RegExp(r'''(\s+)style\s*=\s*(?:"([^"]*)"|'([^']*)')''', caseSensitive: false);

/// Matches legacy presentational colour attributes (`color`, `bgcolor`).
final _legacyColourAttribute =
    RegExp(r'''(\s+)(?:color|bgcolor)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''', caseSensitive: false);

/// Strips inline `color`, `line-height` and background declarations from
/// `style` attributes in [html], as well as legacy `color`/`bgcolor`
/// attributes.
///
/// Some podcast sources (e.g. Ximalaya) embed hard-coded text colours like
/// `color:#333333`, large line-heights like `line-height:30px`, or hard-coded
/// light backgrounds. On a dark theme the text colour is unreadable, and a
/// hard-coded light background combined with the theme's light text is equally
/// unreadable, so both are removed. `background` shorthands that reference an
/// image (`url(...)`) are kept. Removing these declarations lets flutter_html
/// inherit the app theme; all other declarations are preserved.
String stripInlineColors(String html) {
  return html.replaceAllMapped(_htmlTag, (tagMatch) {
    var tag = tagMatch.group(0)!;

    tag = tag.replaceAllMapped(_styleAttribute, (match) {
      final prefix = match.group(1) ?? '';
      final quoted = match.group(2) != null;
      final value = match.group(2) ?? match.group(3) ?? '';
      final kept = value
          .split(';')
          .map((declaration) => declaration.trim())
          .where((declaration) => declaration.isNotEmpty)
          .where(_keepDeclaration)
          .join('; ');

      // Remove the whole attribute (and its leading whitespace) when nothing is
      // left to apply.
      if (kept.isEmpty) return '';

      final quote = quoted ? '"' : "'";

      return '${prefix}style=$quote$kept$quote';
    });

    return tag.replaceAll(_legacyColourAttribute, '');
  });
}

/// Whether a single style declaration should survive the cleanup.
bool _keepDeclaration(String declaration) {
  final separator = declaration.indexOf(':');
  final property = (separator < 0 ? declaration : declaration.substring(0, separator)).trim().toLowerCase();
  final value = separator < 0 ? '' : declaration.substring(separator + 1).trim().toLowerCase();

  switch (property) {
    case 'color':
    case 'line-height':
    case 'background-color':
      return false;
    case 'background':
      // Keep backgrounds that reference an image; plain colours go for the
      // same contrast reason as background-color.
      return value.contains('url(');
    default:
      return true;
  }
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
