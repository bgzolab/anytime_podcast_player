import 'package:anytime/ui/widgets/podcast_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripInlineColors', () {
    test('leaves content without style attributes untouched', () {
      expect(stripInlineColors('<p>Hello</p>'), '<p>Hello</p>');
    });

    test('removes colour declarations', () {
      expect(
        stripInlineColors('<p style="color:#333333;font-size:16px">Hi</p>'),
        '<p style="font-size:16px">Hi</p>',
      );
    });

    test('removes line-height declarations and the attribute when empty', () {
      expect(stripInlineColors('<p style="line-height:30px">Hi</p>'), '<p>Hi</p>');
    });

    test('removes background colours', () {
      expect(
        stripInlineColors('<span style="background-color:#ff0;color:#333">Hi</span>'),
        '<span>Hi</span>',
      );
      expect(stripInlineColors('<span style="background:#ffffff">Hi</span>'), '<span>Hi</span>');
    });

    test('keeps background images', () {
      expect(
        stripInlineColors('<div style="background:url(bg.png) no-repeat">Hi</div>'),
        '<div style="background:url(bg.png) no-repeat">Hi</div>',
      );
    });

    test('handles single quoted style attributes', () {
      expect(stripInlineColors("<p style='color:red'>Hi</p>"), '<p>Hi</p>');
      expect(
        stripInlineColors("<p style='color:red;text-align:center'>Hi</p>"),
        "<p style='text-align:center'>Hi</p>",
      );
    });

    test('keeps the remaining declarations when only some are stripped', () {
      expect(
        stripInlineColors('<p style="color:red;line-height:2;text-align:center">Hi</p>'),
        '<p style="text-align:center">Hi</p>',
      );
    });

    test('matches property names case-insensitively and handles !important', () {
      expect(
        stripInlineColors('<p style="COLOR:red !important;FONT-SIZE:16px">Hi</p>'),
        '<p style="FONT-SIZE:16px">Hi</p>',
      );
    });

    test('removes the style attribute without disturbing other attributes', () {
      expect(
        stripInlineColors('<p class="x" style="color:red" id="y">Hi</p>'),
        '<p class="x" id="y">Hi</p>',
      );
    });

    test('leaves style-like text, selectors and data-style attributes alone', () {
      const bodyText = '<p>Use style="color:red" to set the colour</p>';
      const selector = '<style>[style="color:red"] { colour: red; }</style>';
      const dataAttribute = '<p data-style="color:red">Hi</p>';

      expect(stripInlineColors(bodyText), bodyText);
      expect(stripInlineColors(selector), selector);
      expect(stripInlineColors(dataAttribute), dataAttribute);
    });

    test('does not touch declarations in the document body', () {
      const html = '<style>.foo { color: red; }</style><p>Hi</p>';

      expect(stripInlineColors(html), html);
    });

    test('removes legacy colour attributes', () {
      expect(stripInlineColors('<font color="#333333" face="Arial">Hi</font>'), '<font face="Arial">Hi</font>');
      expect(stripInlineColors("<td bgcolor='#fff' width='10'>Hi</td>"), "<td width='10'>Hi</td>");
      expect(stripInlineColors('<font color=#333>Hi</font>'), '<font>Hi</font>');
    });

    test('never rewrites colour-like text inside other attribute values', () {
      const title = '<a title="use color=red here">Hi</a>';
      const info = '<p data-info="bgcolor=#fff">Hi</p>';

      expect(stripInlineColors(title), title);
      expect(stripInlineColors(info), info);
    });

    test('handles quoted ">" inside attribute values', () {
      expect(stripInlineColors('<p title="a>b" style="color:red">Hi</p>'), '<p title="a>b">Hi</p>');
    });

    test('cleans unquoted style attributes', () {
      expect(stripInlineColors('<p style=color:red>Hi</p>'), '<p>Hi</p>');
      expect(stripInlineColors('<p style=color:red;font-size:16px>Hi</p>'), '<p style="font-size:16px">Hi</p>');
    });

    test('keeps semicolons inside url()', () {
      expect(
        stripInlineColors('<p style="background:url(a;b.png);font-size:16px">Hi</p>'),
        '<p style="background:url(a;b.png); font-size:16px">Hi</p>',
      );
    });

    test('drops the colour fallback of background images', () {
      expect(
        stripInlineColors('<p style="background:#fff url(bg.png)">Hi</p>'),
        '<p style="background:url(bg.png)">Hi</p>',
      );
      expect(
        stripInlineColors('<p style="background:white url(bg.png) no-repeat">Hi</p>'),
        '<p style="background:url(bg.png) no-repeat">Hi</p>',
      );
    });
  });
}
