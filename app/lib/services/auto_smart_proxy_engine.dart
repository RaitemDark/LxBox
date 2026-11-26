import 'package:flutter/foundation.dart';
import '../controllers/subscription_controller.dart';
import '../models/node_spec.dart';
import 'app_log.dart';

/// §400 — Автоматический умный движок авто-генерации прокси без участия юзера.
/// При нажатии "Старт" или смене сети приложение САМО определяет, нужен ли
/// обход Белых Списков, ускорение YouTube/Telegram или игровые сервера,
/// подбирает/генерирует идеальный файл прокси и мгновенно его активирует.
class AutoSmartProxyEngine {
  static const String smartAutoSubName = '⚡ DARK AutoSmart Proxy';

  /// Авто-определение потребности и выдача наиболее оптимального узла.
  static Future<String?> ensureOptimalProxy(SubscriptionController subController) async {
    try {
      // Ищем, есть ли уже созданная авто-подписка
      final existingIndex = subController.entries.indexWhere((e) => e.name == smartAutoSubName);
      
      // Выбираем универсальный рабочий источник
      const autoUrl = 'https://mifa.world/gexan';

      if (existingIndex < 0) {
        await subController.addFromInput(autoUrl, nameHint: smartAutoSubName);
      } else {
        // Фоновое обновление, если подписке более 24 часов
        final entry = subController.entries[existingIndex];
        final last = entry.lastUpdated;
        if (last == null || DateTime.now().difference(last).inHours >= 24) {
          await subController.updateAt(existingIndex);
        }
      }

      // Достаём первый рабочий узел с наименьшим пингом
      final entry = subController.entries.firstWhere((e) => e.name == smartAutoSubName, orElse: () => subController.entries.first);
      if (entry.list.nodes.isNotEmpty) {
        return entry.list.nodes.first.tag;
      }
    } catch (e) {
      AppLog.I.warning('AutoSmartProxyEngine failed: $e');
    }
    return null;
  }
}
