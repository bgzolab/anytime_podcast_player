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

    test('preserves background-color declarations', () {
      expect(
        stripInlineColors('<span style="background-color:#ff0;color:#333">Hi</span>'),
        '<span style="background-color:#ff0">Hi</span>',
      );
    });

    test('handles single quoted style attributes', () {
      expect(stripInlineColors("<p style='color:red'>Hi</p>"), '<p>Hi</p>');
    });

    test('keeps the remaining declarations when only some are stripped', () {
      expect(
        stripInlineColors('<p style="color:red;line-height:2;text-align:center">Hi</p>'),
        '<p style="text-align:center">Hi</p>',
      );
    });

    test('does not touch declarations in the document body', () {
      const html = '<style>.foo { color: red; }</style><p>Hi</p>';

      expect(stripInlineColors(html), html);
    });
  });
}
