import 'package:flutter_test/flutter_test.dart';
import 'package:dark/services/subscription/user_agent.dart';

// Гард фикса «панель отдаёт JSON-конфиг вместо списка подписки». Инварианты:
//   - бренд-токен начинается с `DARK-android/` — по нему substring-панели
//     (Remnawave/Marzban) опознают клиента и отдают base64/URI-список
//     (проверено на боевой vern13);
//   - голого `singbox` (без дефиса, триггер бага) нет нигде; токена `sing-box`
//     и платформенного комментария тоже нет (см. таск 114).
void main() {
  group('buildSubscriptionUserAgent — panel-routing invariants', () {
    test('версия даёт ожидаемую строку', () {
      expect(
        buildSubscriptionUserAgent(appVersion: '2.0.4'),
        'DARK-android/2.0.4',
      );
    });

    test('начинается с бренд-токена DARK-android/', () {
      final ua = buildSubscriptionUserAgent(appVersion: '2.0.4');
      expect(ua.startsWith('DARK-android/'), isTrue, reason: ua);
    });

    test('никогда не содержит "singbox" / "sing-box"', () {
      final ua = buildSubscriptionUserAgent(appVersion: '2.0.4');
      expect(ua.contains('singbox'), isFalse, reason: ua);
      expect(ua.contains('sing-box'), isFalse, reason: ua);
    });

    test('держит dev-версию с дефисами', () {
      expect(
        buildSubscriptionUserAgent(appVersion: '2.0.3-dev.2'),
        'DARK-android/2.0.3-dev.2',
      );
    });

    test('срезает ведущий v и держит инварианты на пустом appVersion', () {
      expect(buildSubscriptionUserAgent(appVersion: ''), 'DARK-android/unknown');
      expect(buildSubscriptionUserAgent(appVersion: 'v2.0.4'), 'DARK-android/2.0.4');
    });

    test('мусор/скобки/пробелы в версии не ломают структуру UA', () {
      final ua = buildSubscriptionUserAgent(appVersion: 'v2.0.4 (dev)');
      expect(ua, 'DARK-android/2.0.4dev');
      expect(ua.contains('singbox'), isFalse, reason: ua);
    });
  });
}
