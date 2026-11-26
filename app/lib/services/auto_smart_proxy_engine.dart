import '../controllers/subscription_controller.dart';
import 'app_log.dart';

/// §400 — Движок авто-генерации ключа прокси без добавления лишних подписок в список.
class AutoSmartProxyEngine {
  /// Просто выдает существующий узел или возвращает null без создания лишней подписки
  static Future<String?> ensureOptimalProxy(SubscriptionController subController) async {
    try {
      if (subController.entries.isNotEmpty) {
        final first = subController.entries.first;
        if (first.list.nodes.isNotEmpty) {
          return first.list.nodes.first.tag;
        }
      }
    } catch (e) {
      AppLog.I.warning('AutoSmartProxyEngine check failed: $e');
    }
    return null;
  }
}
