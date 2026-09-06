import 'package:flutter/material.dart';

import '../../../controllers/home_controller.dart';
import '../../../controllers/subscription_controller.dart';
import '../../../models/home_state.dart';
import '../../../services/format_utils.dart';
import '../../../services/traffic_profiler.dart';
import '../../stats_screen.dart';
import '../../../services/l10n/locale_controller.dart';

/// Полоса трафика под статус-чипом на главном экране: ↑/↓ скорость, число
/// активных соединений, global-recording индикатор профайлера (§044) и uptime.
/// Тап открывает [StatsScreen] (Overview).
///
/// Внешний вид — две карточки (загрузка/отдача) под фирменный дизайн DARK,
/// вместо плоской строки. Источник данных, тап-навигация и recording-индикатор
/// не изменены.
class TrafficBar extends StatelessWidget {
  const TrafficBar({
    super.key,
    required this.state,
    required this.controller,
    this.subController,
  });

  final HomeState state;
  final HomeController controller;

  // §262 — прокидывается в StatsScreen → Live-таб для навигационных кнопок
  // DNS-health листа. null → кнопки навигации не показываются.
  final SubscriptionController? subController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uptime = state.connectedSince != null
        ? formatDuration(
            DateTime.now().difference(state.connectedSince!),
            daysRollup: true,
          )
        : '';
    return GestureDetector(
      onTap: () {
        // §288 — вкладка Per-app удалена; всегда открываем Overview.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsScreen(
              configRaw: controller.state.activeConfigRaw, // §311 — срез ядра
              initialTab: StatsTab.overview,
              subController: subController,
              homeController: controller,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: AnimatedBuilder(
          animation: TrafficProfiler.I,
          builder: (_, _) {
            final profiler = TrafficProfiler.I;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _speedCard(
                      context,
                      icon: Icons.arrow_downward,
                      label: getLocalText.s("Download"),
                      value: state.traffic.downloadFormatted,
                      accent: cs.primary,
                    ),
                    const SizedBox(width: 10),
                    _speedCard(
                      context,
                      icon: Icons.arrow_upward,
                      label: getLocalText.s("Upload"),
                      value: state.traffic.uploadFormatted,
                      accent: cs.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (state.traffic.activeConnections > 0) ...[
                      // §194 — РАЗДЕЛЬНО: connectionsIn = соединения приложений
                      // (трафик-трекер ядра), connectionsOut = физические
                      // соединения наружу к серверам (route-менеджер).
                      _chip(
                        context,
                        Icons.link,
                        '${state.traffic.connectionsIn}',
                        cs.secondary,
                        tooltip: getLocalText.s("App connections"),
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        context,
                        Icons.dns_outlined,
                        '${state.traffic.connectionsOut}',
                        cs.secondary,
                        tooltip: getLocalText.s("Outbound connections to servers"),
                      ),
                    ],
                    if (profiler.isGlobalRecording) ...[
                      const SizedBox(width: 8),
                      _chip(context, Icons.podcasts, 'Live', cs.error),
                    ],
                    const Spacer(),
                    if (uptime.isNotEmpty)
                      Text(
                        uptime,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _speedCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: accent),
                const SizedBox(width: 5),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(
    BuildContext context,
    IconData icon,
    String label,
    Color color, {
    String? tooltip,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
    // §194 — длинное нажатие даёт tooltip (короткий тап ведёт на Stats через
    // GestureDetector полосы). triggerMode.longPress, чтобы не конфликтовать с
    // переходом по тапу.
    if (tooltip == null) return row;
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: row,
    );
  }
}
