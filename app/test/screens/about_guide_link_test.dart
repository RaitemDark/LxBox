import 'package:flutter_test/flutter_test.dart';
import 'package:dark/screens/about_screen.dart';

// §361 — ссылки на документацию (теперь ведут на официальный сайт sing-box).
// Проверяем, что логика выбора языка по-прежнему работает корректно.

void main() {
  group('About → user guide link', () {
    test('ru → русский гайд, en → английский', () {
      expect(AboutScreen.guideUrlFor('ru'), AboutScreen.guideUrlRu);
      expect(AboutScreen.guideUrlFor('en'), AboutScreen.guideUrlEn);
      expect(AboutScreen.guideUrlRu, isNot(AboutScreen.guideUrlEn));
    });

    test('незнакомый язык → английский (fallback)', () {
      for (final tag in ['de', 'fa', 'zh', '']) {
        expect(AboutScreen.guideUrlFor(tag), AboutScreen.guideUrlEn,
            reason: 'тег "$tag" должен падать в английскую версию');
      }
    });

    test('URL смотрят на официальный сайт sing-box', () {
      for (final url in [AboutScreen.guideUrlEn, AboutScreen.guideUrlRu]) {
        expect(url, startsWith('https://sing-box.sagernet.org/'));
      }
    });
  });
}
