import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/donate_methods.dart';
import '../services/install_source.dart';
import '../services/project_links.dart';
import '../vpn/box_vpn_client.dart';
import '../services/version_info.dart';
import '../services/url_launcher.dart' as ul;
import '../services/l10n/locale_controller.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.openDonate = false});

  /// §362 — открыть донат-попап сразу после первого кадра: кнопка
  /// `dark://route:donate` в support-ленте ведёт к способам поддержки
  /// ВНУТРИ приложения, а не на внешнюю страницу.
  final bool openDonate;

  static const guideUrlEn = ProjectLinks.guideEn;
  static const guideUrlRu = ProjectLinks.guideRu;

  /// Ссылка на руководство под язык интерфейса. Незнакомый тег (язык, для
  /// которого гайда ещё нет) → английская версия, а не 404.
  @visibleForTesting
  static String guideUrlFor(String tag) => ProjectLinks.guideFor(tag);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (openDonate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showDonateDialog(context);
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(getLocalText.s("About"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // l10n-exempt: app name
                  'DARK',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  // l10n-exempt: version literal, no translatable words
                  'v${VersionInfo.I.version}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                // §390 — канал установки. Полезен в багрепортах: от него
                // зависят и подпись APK, и адрес обновления.
                Text(
                  getLocalText.s(
                      "Installed from %s", InstallSourceResolver.current.label),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                // VPN core version — runtime через `Libbox.version()`. Ссылка
                // на внешний источник убрана: показываем только версию, без
                // перехода куда-либо.
                FutureBuilder<String>(
                  future: BoxVpnClient.I.getCoreVersion(),
                  builder: (ctx, snap) {
                    final v = (snap.data ?? '').trim();
                    final subtitle = switch (snap.connectionState) {
                      ConnectionState.waiting => 'Loading…',
                      _ when v.isEmpty => 'sing-box (version unknown)',
                      _ => 'sing-box $v · via libbox',
                    };
                    return ListTile(
                      leading: const Icon(Icons.architecture),
                      title: Text(getLocalText.s("VPN core")),
                      subtitle: Text(subtitle),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite),
            label: Text(getLocalText.s("Support the project")),
          ),
          const SizedBox(height: 16),
          Text(
            getLocalText.s("Tech Stack"),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              // l10n-exempt: technology name
              Chip(label: Text('Flutter')),
              // l10n-exempt: technology name
              Chip(label: Text('Dart')),
              // l10n-exempt: technology name
              Chip(label: Text('sing-box')),
              // l10n-exempt: technology name
              Chip(label: Text('libbox')),
              // l10n-exempt: technology name
              Chip(label: Text('CommandClient')),
              // l10n-exempt: technology name
              Chip(label: Text('Material 3')),
            ],
          ),
        ],
      ),
    );
  }

  /// §362 — попап поддержки строится из `assets/donate.json`
  /// ([DonateMethods]), а не из вшитой в разметку таблицы адресов: добавить
  /// сеть = дописать запись в JSON. Пустой/битый файл → в попапе остаётся
  /// ссылка на веб-страницу поддержки, а не пустота.
  void _showDonateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(getLocalText.s("Support DARK")),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<DonateMethod>>(
            future: DonateMethods.I.load(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final methods = snap.data ?? const <DonateMethod>[];
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final m in methods) ...[
                    _DonateTile(method: m, onCopy: _copyToClipboard),
                    const Divider(height: 20),
                  ],
                  TextButton.icon(
                    onPressed: () => ul.UrlLauncher.open(
                        ProjectLinks.donatePageFor(
                            LocaleController.I.effectiveTag)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(getLocalText.s("All ways to support")),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(getLocalText.s("Close"))),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(getLocalText.s("Copied: %s", text))),
    );
  }
}

/// §362 — строка способа поддержки в попапе. `crypto`: название, адрес
/// моноширинным (тап/кнопка — копирование) и кнопка оплаты (deeplink
/// кошелька). `link`: одна кнопка. `note` необязателен.
class _DonateTile extends StatelessWidget {
  const _DonateTile({required this.method, required this.onCopy});

  final DonateMethod method;
  final void Function(BuildContext, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = method.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // l10n-exempt: network / brand name
        Text(method.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(note,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
        if (method.isCrypto) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onCopy(context, method.address!),
            // l10n-exempt: wallet address
            child: Text(method.address!,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onCopy(context, method.address!),
                icon: const Icon(Icons.copy, size: 14),
                label: Text(getLocalText.s("Copy"),
                    style: const TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => ul.UrlLauncher.open(method.url),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                label: Text(getLocalText.s("Pay"),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 4),
          FilledButton.tonal(
            onPressed: () => ul.UrlLauncher.open(method.url),
            child: Text(getLocalText.s("Open")),
          ),
        ],
      ],
    );
  }
}
