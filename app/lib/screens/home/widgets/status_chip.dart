import 'package:flutter/material.dart';

import '../../../models/home_state.dart';

/// Статус-чип VPN-туннеля в connect-controls на главном экране: иконка щита +
/// label текущего [TunnelStatus]. Во время connecting иконка вращается
/// ([connectingAnim], которым управляет `_HomeScreenState` вне build-фазы).
///
/// UI-маппинг: revoked и `unknown` показываются как disconnected (нейтральный
/// off-state — факт revoke юзер получает через SnackBar, не алармирующий чип).
///
/// Внешний вид — под фирменный дизайн DARK (крупнее, с акцентной подложкой),
/// логика и источники данных не изменены.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.state,
    required this.isRevoked,
    required this.isConnecting,
    required this.connectingAnim,
  });

  final HomeState state;
  final bool isRevoked;
  final bool isConnecting;
  final Animation<double> connectingAnim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = state.tunnelUp
        ? Icons.shield
        : isConnecting
            ? Icons.sync
            : Icons.shield_outlined;
    final color = state.tunnelUp ? cs.primary : cs.onSurfaceVariant;
    final label = (isRevoked || state.tunnel == TunnelStatus.unknown)
        ? TunnelStatus.disconnected.label()
        : state.tunnel.label();

    Widget iconWidget = Icon(icon, size: 16, color: color);
    if (isConnecting) {
      iconWidget = AnimatedBuilder(
        animation: connectingAnim,
        builder: (_, child) => Transform.rotate(
          angle: connectingAnim.value * 2 * 3.14159,
          child: child,
        ),
        child: iconWidget,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: state.tunnelUp
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 6),
          // Длинные локализованные статусы («Подключено») сжимаются вместо
          // того, чтобы выдавливать соседей.
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
