// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:url_launcher/url_launcher.dart';

/// Strips inline `color`, `line-height` and background declarations from
/// `style` attributes in [html], as well as legacy `color`/`bgcolor`
/// attributes.
///
/// Some podcast sources (e.g. Ximalaya) embed hard-coded text colours like
/// `color:#333333`, large line-heights like `line-height:30px`, or hard-coded
/// light backgrounds. On a dark theme the text colour is unreadable, and a
/// hard-coded light background combined with the theme's light text is equally
/// unreadable, so both are removed. `background` shorthands that reference an
/// image (`url(...)`) are kept, but their colour fallback is dropped. Removing
/// these declarations lets flutter_html inherit the app theme; all other
/// declarations are preserved.
///
/// Only tags are rewritten: text, `<script>` strings and `<style>` selectors
/// that happen to contain `style="…"` are left alone. Attributes are parsed
/// manually, respecting quoted values, so an unrelated attribute such as
/// `title="use color=red here"` is never touched.
String stripInlineColors(String html) {
  final out = StringBuffer();
  var i = 0;

  while (i < html.length) {
    final tagStart = html.indexOf('<', i);

    if (tagStart < 0) {
      out.write(html.substring(i));
      break;
    }

    out.write(html.substring(i, tagStart));

    final nameStart = tagStart + 1;

    if (nameStart < html.length && _isAsciiLetter(html.codeUnitAt(nameStart))) {
      final tagEnd = _findTagEnd(html, nameStart);

      if (tagEnd < 0) {
        // Unterminated tag: keep the rest of the document as-is.
        out.write(html.substring(tagStart));
        break;
      }

      out.write(_cleanTag(html.substring(tagStart, tagEnd + 1)));
      i = tagEnd + 1;
    } else {
      // Comment, doctype, closing tag or a stray '<': copy and continue.
      out.write('<');
      i = tagStart + 1;
    }
  }

  return out.toString();
}

/// Returns the index of the `>` that closes the tag whose name starts at
/// [nameStart], skipping over quoted attribute values. Returns -1 when the tag
/// is unterminated.
int _findTagEnd(String html, int nameStart) {
  var i = nameStart;

  // A quote only starts an attribute value directly after '=' (whitespace may
  // sit in between); quotes inside unquoted values (e.g. `it's`) are data.
  var quotePending = false;

  while (i < html.length) {
    final char = html[i];

    if (quotePending && (char == '"' || char == "'")) {
      final close = html.indexOf(char, i + 1);

      if (close < 0) return -1;

      i = close + 1;
      quotePending = false;
      continue;
    }

    if (char == '>') return i;

    if (!_isWhitespace(html.codeUnitAt(i))) {
      quotePending = char == '=';
    }

    i++;
  }

  return -1;
}

/// Cleans the attributes of a single start tag (`<name …>`).
String _cleanTag(String tag) {
  final out = StringBuffer();
  var i = 0;

  // Copy '<' and the tag name verbatim.
  while (i < tag.length && !_isWhitespace(tag.codeUnitAt(i))) {
    out.write(tag[i]);
    i++;
  }

  while (i < tag.length) {
    final whitespaceStart = i;

    while (i < tag.length && _isWhitespace(tag.codeUnitAt(i))) {
      i++;
    }

    final whitespace = tag.substring(whitespaceStart, i);

    if (i >= tag.length || tag[i] == '>' || tag[i] == '/') {
      // End of the tag or its self-closing slash.
      out.write(whitespace);
      out.write(tag.substring(i));
      break;
    }

    final nameStart = i;

    while (i < tag.length && !_isWhitespace(tag.codeUnitAt(i)) && tag[i] != '=' && tag[i] != '>' && tag[i] != '/') {
      i++;
    }

    final name = tag.substring(nameStart, i).toLowerCase();

    // HTML allows whitespace around the '=' of an attribute.
    var valueStart = i;

    while (valueStart < tag.length && _isWhitespace(tag.codeUnitAt(valueStart))) {
      valueStart++;
    }

    String? value;
    String? quote;

    if (valueStart < tag.length && tag[valueStart] == '=') {
      i = valueStart + 1;

      while (i < tag.length && _isWhitespace(tag.codeUnitAt(i))) {
        i++;
      }

      if (i < tag.length && (tag[i] == '"' || tag[i] == "'")) {
        quote = tag[i];
        i++;

        final valueStart = i;

        while (i < tag.length && tag[i] != quote) {
          i++;
        }

        value = tag.substring(valueStart, i);

        if (i < tag.length) i++; // closing quote
      } else {
        final valueStart = i;

        while (i < tag.length && !_isWhitespace(tag.codeUnitAt(i)) && tag[i] != '>') {
          i++;
        }

        value = tag.substring(valueStart, i);
      }
    }

    if (name == 'style') {
      final kept = value == null ? '' : _cleanStyleValue(value);

      // Drop the whole attribute (and its leading whitespace) when nothing is
      // left to apply.
      if (kept.isNotEmpty) {
        final q = quote ?? '"';

        out.write(whitespace);
        out.write('style=$q$kept$q');
      }
    } else if (name == 'color' || name == 'bgcolor') {
      // Legacy presentational colour attributes are dropped.
    } else {
      out.write(whitespace);
      out.write(tag.substring(nameStart, i));
    }
  }

  return out.toString();
}

/// Cleans a single `style` attribute value and returns the declarations that
/// survive, without the surrounding quotes. Empty when nothing survives.
String _cleanStyleValue(String value) {
  final kept = <String>[];

  for (final declaration in _splitDeclarations(value)) {
    final trimmed = declaration.trim();

    if (trimmed.isEmpty) continue;

    final separator = trimmed.indexOf(':');
    final property = (separator < 0 ? trimmed : trimmed.substring(0, separator)).trim().toLowerCase();

    switch (property) {
      case 'color':
      case 'line-height':
      case 'background-color':
        break;
      case 'background':
        if (separator < 0) break;

        final cleaned = _stripBackgroundColour(trimmed.substring(separator + 1));

        if (cleaned != null) {
          kept.add('${trimmed.substring(0, separator).trim()}:$cleaned');
        }
        break;
      default:
        kept.add(trimmed);
    }
  }

  return kept.join('; ');
}

/// Splits a style value on semicolons, ignoring semicolons inside parentheses
/// (e.g. `url(a;b.png)`).
List<String> _splitDeclarations(String value) {
  final declarations = <String>[];
  final current = StringBuffer();
  var depth = 0;
  String? quote;

  for (var i = 0; i < value.length; i++) {
    final char = value[i];

    // Quoted strings (e.g. font-family:'a;b') must not be split.
    if (quote != null) {
      if (char == '\\' && i + 1 < value.length) {
        // An escaped character stays inside the string.
        current.write(char);
        current.write(value[i + 1]);
        i++;
        continue;
      }

      if (char == quote) quote = null;

      current.write(char);
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      current.write(char);
      continue;
    }

    if (char == '(') depth++;
    if (char == ')' && depth > 0) depth--;

    if (char == ';' && depth == 0) {
      declarations.add(current.toString());
      current.clear();
      continue;
    }

    current.write(char);
  }

  declarations.add(current.toString());

  return declarations;
}

/// Matches the non-colour parts of a `background` shorthand: layout and box
/// keywords, lengths/percentages and the `/` position-size separator.
final _backgroundKeyword = RegExp(
  r'^(repeat(-x|-y)?|no-repeat|space|round|fixed|local|scroll|left|right|top|bottom|center|cover|contain|border-box|padding-box|content-box|none|inherit|initial|unset|revert)$'
  r'|^[+-]?[\d.]+(%|px|em|rem|vh|vw|vmin|vmax|pt|pc|cm|mm|in|q)?$',
  caseSensitive: false,
);

/// Removes the colour components from a `background` shorthand value while
/// keeping the image reference and the layout keywords.
///
/// Colours may appear before or after `url(...)` (the CSS `||` combinator
/// allows any order), so the value is tokenised outside parentheses rather
/// than only looking before the image. A bare token that is neither a layout
/// keyword/length nor a `url(...)` is treated as a colour and dropped, which
/// also covers the long tail of named CSS colours. Minified values that glue
/// colours and images together (`red,url(a.png)`) keep their `url(...)` parts.
///
/// Returns null when the value has no image reference (a plain colour).
String? _stripBackgroundColour(String value) {
  if (!value.toLowerCase().contains('url(')) return null;

  final kept = <String>[];
  final current = StringBuffer();
  var depth = 0;

  void addToken(String token) {
    final trimmed = token.trim();

    if (trimmed.isEmpty) return;

    final lower = trimmed.toLowerCase();

    if (_isBackgroundKeywordToken(lower)) {
      kept.add(trimmed);

      return;
    }

    if (lower.contains('url(')) {
      for (final match in RegExp(r'url\([^)]*\)', caseSensitive: false).allMatches(trimmed)) {
        kept.add(match.group(0)!);
      }
    }
  }

  for (var i = 0; i < value.length; i++) {
    final char = value[i];

    if (char == '(') depth++;
    if (char == ')' && depth > 0) depth--;

    if (depth == 0 && (char == ',' || _isWhitespace(char.codeUnitAt(0)))) {
      addToken(current.toString());
      current.clear();

      if (char == ',') kept.add(',');

      continue;
    }

    current.write(char);
  }

  addToken(current.toString());

  if (kept.isEmpty) return null;

  // Normalise the separators: commas left at the edges or doubled up by
  // removed colour layers are dropped.
  final joined = kept.join(' ').replaceAll(RegExp(r'\s*,\s*'), ', ');
  final parts = joined.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

  return parts.isEmpty ? null : parts.join(', ');
}

/// Whether [token] consists only of non-colour `background` keywords, lengths
/// or the `/` position/size separator.
bool _isBackgroundKeywordToken(String token) {
  if (token == '/') return true;

  return token.split('/').every((part) => _backgroundKeyword.hasMatch(part));
}

bool _isWhitespace(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D;

bool _isAsciiLetter(int codeUnit) => (codeUnit >= 0x41 && codeUnit <= 0x5A) || (codeUnit >= 0x61 && codeUnit <= 0x7A);

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
