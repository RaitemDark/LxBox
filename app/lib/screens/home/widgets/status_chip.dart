import 'package:flutter/material.dart';

import '../../../models/home_state.dart';
import '../../../services/real_ip_lookup_service.dart';

/// Статус-чип VPN-туннеля в connect-controls на главном экране
class StatusChip extends StatefulWidget {
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
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip> {
  @override
  void initState() {
    super.initState();
    _checkIpIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.tunnelUp && !oldWidget.state.tunnelUp) {
      _checkIpIfNeeded();
    }
  }

  Future<void> _checkIpIfNeeded() async {
    if (widget.state.tunnelUp) {
      final info = await RealIpLookupService.lookupRealIp();
      if (mounted && info != null) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = widget.state.tunnelUp
        ? Icons.shield
        : widget.isConnecting
            ? Icons.sync
            : Icons.shield_outlined;
    final color = widget.state.tunnelUp ? cs.primary : cs.onSurfaceVariant;
    
    final ipInfo = widget.state.tunnelUp ? RealIpLookupService.cachedInfo : null;
    String label;
    if (widget.state.tunnelUp && ipInfo != null) {
      label = '${ipInfo.flagEmoji} ${ipInfo.ip} (${ipInfo.countryName})';
    } else {
      label = (widget.isRevoked || widget.state.tunnel == TunnelStatus.unknown)
          ? TunnelStatus.disconnected.label()
          : widget.state.tunnel.label();
    }

    Widget iconWidget = Icon(icon, size: 16, color: color);
    if (widget.isConnecting) {
      iconWidget = AnimatedBuilder(
        animation: widget.connectingAnim,
        builder: (_, child) => Transform.rotate(
          angle: widget.connectingAnim.value * 2 * 3.14159,
          child: child,
        ),
        child: iconWidget,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: widget.state.tunnelUp
            ? cs.primary.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.state.tunnelUp ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
