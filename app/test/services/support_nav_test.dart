import 'package:flutter_test/flutter_test.dart';
import 'package:dark/services/support/support_nav.dart';

/// §357 — парсер `dark://action:payload` и резолвабельность действий.
void main() {
  group('SupportLinkAction.parse', () {
    test('route: экран и экран/вкладка', () {
      final a = SupportLinkAction.parse('dark://route:dns')!;
      expect(a.action, 'route');
      expect(a.payload, 'dns');
      expect(routeSegments(a), ['dns']);

      final b = SupportLinkAction.parse('dark://route:debug/profiling')!;
      expect(routeSegments(b), ['debug', 'profiling']);
    });

    test('payload — целый URI со своим ://, query и фрагментом', () {
      const uri =
          'vless://uuid@154.83.246.52:443?flow=xtls-rprx-vision&sni=x#%F0%9F%87%B3%F0%9F%87%B1';
      final a = SupportLinkAction.parse('dark://add:$uri')!;
      expect(a.action, 'add');
      expect(a.payload, uri, reason: 'всё после первого ":" — сырой payload');
    });

    test('не-dark и битые → null', () {
      expect(SupportLinkAction.parse('https://***/x'), isNull);
      expect(SupportLinkAction.parse('dark://route'), isNull,
          reason: 'нет разделителя действия');
      expect(SupportLinkAction.parse('dark://route:'), isNull,
          reason: 'пустой payload');
      expect(SupportLinkAction.parse('dark://:dns'), isNull,
          reason: 'пустое действие');
      expect(SupportLinkAction.parse(''), isNull);
    });
  });

  group('isResolvableSupportAction', () {
    test('route: все экраны реестра резолвятся', () {
      for (final s in kSupportRouteScreens) {
        expect(
            isResolvableSupportAction(SupportLinkAction.parse('dark://route:$s')!),
            true,
            reason: s);
      }
    });

    test('route: неизвестный экран / add: пустой / чужое действие → false', () {
      expect(
          isResolvableSupportAction(
              SupportLinkAction.parse('dark://route:teleport')!),
          false);
      expect(
          isResolvableSupportAction(SupportLinkAction.parse('dark://add: ')!),
          false);
      expect(
          isResolvableSupportAction(
              SupportLinkAction.parse('dark://teleport:mars')!),
          false,
          reason: 'forward-compat: будущие действия старые версии прячут');
    });

    test('share: непустой payload резолвится и НЕ уводит с экрана', () {
      final a = SupportLinkAction.parse('dark://share:Смотри — DARK https://x')!;
      expect(a.action, 'share');
      expect(isResolvableSupportAction(a), true);
      expect(isInPlaceSupportAction(a), true);
      expect(
          isResolvableSupportAction(SupportLinkAction.parse('dark://share:   ')!),
          false);
      // route/add — уводят (pushReplacement), не in-place.
      expect(
          isInPlaceSupportAction(SupportLinkAction.parse('dark://route:dns')!),
          false);
    });

    test('route:about/donate — донат вкладкой, отдельного слага нет', () {
      final a = SupportLinkAction.parse('dark://route:about/donate')!;
      expect(routeSegments(a), ['about', 'donate']);
      expect(isResolvableSupportAction(a), true);
      expect(
          isResolvableSupportAction(SupportLinkAction.parse('dark://route:donate')!),
          false,
          reason: 'донат — состояние About, а не самостоятельный экран');
    });

    test('route: вкладка не влияет на резолвабельность', () {
      expect(
          isResolvableSupportAction(
              SupportLinkAction.parse('dark://route:debug/whatever')!),
          true,
          reason: 'неизвестная вкладка деградирует к дефолтной на экране');
    });
  });
}
