import 'package:flutter/material.dart';
import '../../../services/l10n/locale_controller.dart';
import '../../../services/settings_storage.dart';

class QuickDnsSheet extends StatefulWidget {
  const QuickDnsSheet({super.key, required this.onChanged});

  final VoidCallback onChanged;

  static Future<void> show(BuildContext context, VoidCallback onChanged) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuickDnsSheet(onChanged: onChanged),
    );
  }

  @override
  State<QuickDnsSheet> createState() => _QuickDnsSheetState();
}

class _QuickDnsSheetState extends State<QuickDnsSheet> {
  String _activeDns = 'default';

  @override
  void initState() {
    super.initState();
    _loadCurrentDns();
  }

  Future<void> _loadCurrentDns() async {
    final cur = await SettingsStorage.getVar('quick_dns_preset', 'default');
    if (mounted) setState(() => _activeDns = cur);
  }

  Future<void> _selectDns(String key, String address) async {
    await SettingsStorage.setVar('quick_dns_preset', key);
    if (key != 'default') {
      await SettingsStorage.setVar('custom_dns_server', address);
    } else {
      await SettingsStorage.setVar('custom_dns_server', '');
    }
    widget.onChanged();
    if (mounted) Navigator.pop(context);
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
                getLocalText.s("Quick DNS Proxy"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: _activeDns == 'default' ? cs.primaryContainer.withValues(alpha: 0.3) : null,
            leading: const Icon(Icons.shield_outlined),
            title: Text(getLocalText.s("Standard DNS")),
            subtitle: Text(getLocalText.s("Default system resolvers"), style: const TextStyle(fontSize: 12)),
            trailing: _activeDns == 'default' ? Icon(Icons.check_circle, color: cs.primary) : null,
            onTap: () => _selectDns('default', ''),
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: _activeDns == 'nulls' ? cs.primaryContainer.withValues(alpha: 0.3) : null,
            leading: const Icon(Icons.sports_esports_outlined, color: Colors.amber),
            title: const Text("Null's Brawl DNS (dns.nullsproxy.com)"),
            subtitle: Text(getLocalText.s("Brawl Stars & Null's games proxy DNS"), style: const TextStyle(fontSize: 12)),
            trailing: _activeDns == 'nulls' ? Icon(Icons.check_circle, color: cs.primary) : null,
            onTap: () => _selectDns('nulls', 'https://dns.nullsproxy.com/dns-query'),
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: _activeDns == 'comss' ? cs.primaryContainer.withValues(alpha: 0.3) : null,
            leading: const Icon(Icons.speed_outlined, color: Colors.cyan),
            title: const Text("Comss DNS (router.comss.one)"),
            subtitle: Text(getLocalText.s("Anti-blocking Comss DNS proxy"), style: const TextStyle(fontSize: 12)),
            trailing: _activeDns == 'comss' ? Icon(Icons.check_circle, color: cs.primary) : null,
            onTap: () => _selectDns('comss', 'https://router.comss.one/dns-query'),
          ),
        ],
      ),
    );
  }
}
