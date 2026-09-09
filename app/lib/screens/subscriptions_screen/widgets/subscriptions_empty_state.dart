import 'package:flutter/material.dart';

import '../../../services/l10n/locale_controller.dart';

/// Onboarding card (night T5-1): вместо голого "No subscriptions yet"
/// показываем карточку с 3-step start — пользователь сразу видит что
/// делать. ListView+AlwaysScrollable чтобы pull-to-refresh (T3-2)
/// продолжал работать на пустом экране.
///
/// Внешний вид — под фирменный дизайн DARK (крупная иконка-плашка с мягким
/// свечением, карточка с рамкой вместо плоской заливки). Текст и логика
/// не изменены.
class SubscriptionsEmptyState extends StatelessWidget {
  const SubscriptionsEmptyState({
    super.key,
    required this.busy,
  });

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.rocket_launch, color: cs.primary, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(getLocalText.s("Getting started"),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _step(context, '1',
                    getLocalText.s("1. Get a subscription URL from your VPN provider, or a direct proxy link (vless://, trojan://, vmess://, ss://…).")),
                const SizedBox(height: 10),
                _step(context, '2',
                    getLocalText.s("2. Paste it into the field above, or tap ⋮ → «Paste from clipboard», «Scan QR code».")),
                const SizedBox(height: 10),
                _step(context, '3',
                    getLocalText.s("3. Hit «+». DARK will fetch, parse and configure — and you can connect from the Home tab.")),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            getLocalText.s("Tip: pull down to refresh, or tap ⟳ in the top bar after adding."),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  static Widget _step(BuildContext context, String number, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: 0.15),
          ),
          child: Text(number,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
