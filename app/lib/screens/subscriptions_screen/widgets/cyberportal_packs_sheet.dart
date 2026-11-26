import 'package:flutter/material.dart';
import '../../../controllers/subscription_controller.dart';
import '../../../services/app_log.dart';
import '../../../services/error_format.dart';
import '../../../services/l10n/locale_controller.dart';

/// Диалог выбора пака Киберпортал (CP-001 ... CP-043)
class CyberportalPacksSheet extends StatefulWidget {
  const CyberportalPacksSheet({
    super.key,
    required this.subController,
    required this.onAdded,
  });

  final SubscriptionController subController;
  final VoidCallback onAdded;

  static Future<void> show(
    BuildContext context,
    SubscriptionController subController,
    VoidCallback onAdded,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CyberportalPacksSheet(
        subController: subController,
        onAdded: onAdded,
      ),
    );
  }

  @override
  State<CyberportalPacksSheet> createState() => _CyberportalPacksSheetState();
}

class _CyberportalPacksSheetState extends State<CyberportalPacksSheet> {
  bool _loading = false;
  String _selectedPackCode = 'CP-002';

  static const _packs = <(String code, String name, String url)>[
    ('CP-001', 'Shadowsocks All RU', 'https://raw.githubusercontent.com/whoahaow/rjsxrd/refs/heads/main/githubmirror/bypass/bypass-1.txt'),
    ('CP-002', 'VLESS Black All RU', 'https://github.com/PizdukMod/PizdukVPN/raw/refs/heads/main/sub'),
    ('CP-003', 'VLESS Black Mobile RU', 'https://raw.githubusercontent.com/flaafix/AetrisVPN-black-list/main/configs.txt'),
    ('CP-005', 'VLESS Reality Mobile', 'https://s3.twcstorage.ru/cd58536-mhand-bucket/vless/vless_mhand.txt'),
    ('CP-006', 'CIDR White All RU', 'https://github.com/PizdukMod/PizdukVPN/raw/refs/heads/main/wl'),
    ('CP-007', 'CIDR White Checked RU', 'https://raw.githubusercontent.com/flaafix/AetrisVPN/main/AetrisVPN.txt'),
    ('CP-008', 'SNI White All RU', 'https://raw.githubusercontent.com/zieng2/wl/main/vless_universal.txt'),
    ('CP-009', 'White List · LTE 3', 'https://raw.githubusercontent.com/flaafix/AetrisVPN-white-list-lite/main/AetrisVPN.txt'),
    ('CP-037', 'TCP Pack', 'https://gidroksi.fun/black-list'),
    ('CP-038', 'White List Lite', 'https://raw.githubusercontent.com/flaafix/AetrisVPN-white-list-lite/main/AetrisVPN.txt'),
    ('CP-039', 'VLESS Lite', 'https://gist.githubusercontent.com/Diman331/8c868070c0b5a5ec0c7d94507717b67b/raw/subscription.txt'),
    ('CP-040', 'Extended WL', 'https://raw.githubusercontent.com/flaafix/AetrisVPN/main/AetrisVPN.txt'),
    ('CP-041', 'Full Mix', 'https://mifa.world/gexan'),
    ('CP-042', 'White Keys', 'https://github.com/PizdukMod/PizdukVPN/raw/refs/heads/main/wl'),
    ('CP-043', 'Black List · GRIBI', 'https://raw.githubusercontent.com/flaafix/AetrisVPN-black-list/main/configs.txt'),
  ];

  Future<void> _importPack() async {
    final pack = _packs.firstWhere((p) => p.$1 == _selectedPackCode, orElse: () => _packs.first);
    setState(() => _loading = true);
    try {
      await widget.subController.addFromInput(pack.$3, nameHint: '${pack.$1} — ${pack.$2}');
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppLog.I.warning('Import pack error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalText.s("Error: %s", formatUserError(e).render()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                getLocalText.s("Cyberportal Pack Selector"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            getLocalText.s("Select a pack to automatically generate and import servers for Telegram, YouTube and White Lists."),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedPackCode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: getLocalText.s("Select pack"),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _packs.map((p) {
              return DropdownMenuItem<String>(
                value: p.$1,
                child: Text('${p.$1} — ${p.$2}', style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPackCode = val);
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _importPack,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(getLocalText.s("Import selected pack")),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
