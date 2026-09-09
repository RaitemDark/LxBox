import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Результат проверки сети.
enum NetworkAccessLevel {
  /// Не проверяли ещё, или проверка идёt.
  unknown,

  /// Обычный интернет — иностранные сайты открываются.
  fullAccess,

  /// Иностранные сайты недоступны, но локальные (ya.ru/vk.ru) открываются —
  /// похоже на режим "только белый список" у провайдера/оператора.
  whitelistOnly,
}

/// Проверяет, не работает ли сейчас интернет в режиме "только белый список"
/// (когда провайдер пропускает лишь ограниченный набор российских сайтов,
/// а остальной мир недоступен). Логика: HEAD-запрос с коротким таймаутом на
/// несколько заведомо разных иностранных доменов + пару российских; если
/// иностранные не отвечают (ConnectException/таймаут), а российские
/// отвечают — заключаем, что включены "белые списки".
class WhitelistDetector {
  WhitelistDetector._();
  static final WhitelistDetector I = WhitelistDetector._();

  static const _foreignProbes = [
    'https://www.google.com',
    'https://www.cloudflare.com',
    'https://www.wikipedia.org',
    'https://example.com',
    'https://www.gstatic.com',
  ];

  static const _localProbes = [
    'https://ya.ru',
    'https://vk.ru',
  ];

  static const _timeout = Duration(seconds: 3);

  /// Один прогон проверки. Не бросает исключений — при любой внутренней
  /// ошибке возвращает [NetworkAccessLevel.unknown] (не мешаем юзеру ложной
  /// тревогой, если сама проверка не удалась технически).
  Future<NetworkAccessLevel> check() async {
    try {
      final foreignOk = await _anyReachable(_foreignProbes);
      if (foreignOk) return NetworkAccessLevel.fullAccess;

      final localOk = await _anyReachable(_localProbes);
      return localOk ? NetworkAccessLevel.whitelistOnly : NetworkAccessLevel.unknown;
    } catch (_) {
      return NetworkAccessLevel.unknown;
    }
  }

  /// true, если хотя бы один адрес из списка ответил (любой HTTP-статус —
  /// нам важен сам факт TCP/TLS-соединения, а не код ответа).
  Future<bool> _anyReachable(List<String> urls) async {
    final client = http.Client();
    try {
      final results = await Future.wait(
        urls.map((u) => _probeOne(client, u)),
        eagerError: false,
      );
      return results.any((ok) => ok);
    } finally {
      client.close();
    }
  }

  Future<bool> _probeOne(http.Client client, String url) async {
    try {
      await client.head(Uri.parse(url)).timeout(_timeout);
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
