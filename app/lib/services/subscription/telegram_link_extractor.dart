import 'package:http/http.dart' as http;
import '../app_log.dart';

/// Извлекает актуальную ссылку подписки (например, https://mifa.world/mirex)
/// из текста публичного поста в Telegram (например, https://t.me/mifa_world/1310/42161).
Future<String?> extractSubscriptionUrlFromTelegram(String url) async {
  try {
    var fetchUrl = url.trim();
    if (!fetchUrl.contains('t.me/')) return null;

    // Превращаем t.me/channel/post в t.me/s/channel/post для публичного HTML-превью
    if (fetchUrl.contains('t.me/') && !fetchUrl.contains('t.me/s/')) {
      fetchUrl = fetchUrl.replaceAll('t.me/', 't.me/s/');
    }

    final response = await http.get(
      Uri.parse(fetchUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final body = response.body;
      // Ищем ссылку вида https://mifa.world/... или любую прямую подписочную ссылку
      final match = RegExp(r'https?://mifa\.world/[a-zA-Z0-9_\-]+').firstMatch(body);
      if (match != null) {
        final extracted = match.group(0);
        AppLog.I.info('Telegram Extractor: found "$extracted" from "$url"');
        return extracted;
      }
    }
  } catch (e) {
    AppLog.I.warning('Telegram Extractor failed for "$url": $e');
  }
  return null;
}
