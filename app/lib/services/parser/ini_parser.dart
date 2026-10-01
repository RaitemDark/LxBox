import '../../models/node_spec.dart';
import 'uri_utils.dart';

/// Парсинг WireGuard / AmneziaWG INI → WireguardSpec (§3.3).
///
/// Обязательные поля: `[Interface].PrivateKey`, `[Peer].PublicKey`,
/// `[Peer].Endpoint`. Остальные — опциональные с дефолтами.
WireguardSpec? parseWireguardIni(String config, {String? nameHint}) {
  final lines = config.split(RegExp(r'\r?\n'));
  String section = '';
  String privateKey = '';
  String address = '';
  String publicKey = '';
  String endpoint = '';
  String allowedIps = '';
  String presharedKey = '';
  String reserved = '';
  int mtu = 0;
  int keepalive = 0;
  final awg = <String, String>{};

  for (final line in lines) {
    final t = line.trim();
    if (t.startsWith('[')) {
      section = t.toLowerCase();
      continue;
    }
    final idx = t.indexOf('=');
    if (idx < 0) continue;
    final k = t.substring(0, idx).trim().toLowerCase();
    final v = t.substring(idx + 1).trim();
    if (section == '[interface]') {
      if (k == 'privatekey') privateKey = v;
      if (k == 'address') address = v;
      if (k == 'mtu') mtu = int.tryParse(v) ?? 0;
      if (Awg.numKeys.contains(k) || Awg.strKeys.contains(k)) awg[k] = v;
    } else if (section == '[peer]') {
      if (k == 'publickey') publicKey = v;
      if (k == 'endpoint') endpoint = v;
      if (k == 'allowedips') allowedIps = v;
      if (k == 'presharedkey') presharedKey = v;
      if (k == 'persistentkeepalive') keepalive = int.tryParse(v) ?? 0;
      if (k == 'reserved' || k == 'client_id' || k == 'clientid') reserved = v;
    }
  }

  if (privateKey.isEmpty || publicKey.isEmpty || endpoint.isEmpty) return null;

  final normPriv = normalizeWGKey(privateKey) ?? privateKey;
  final normPub = normalizeWGKey(publicKey) ?? publicKey;

  String host;
  int port = 51820;
  if (endpoint.startsWith('[')) {
    final close = endpoint.indexOf(']');
    host = endpoint.substring(1, close > 0 ? close : endpoint.length);
    final after = close > 0 ? endpoint.substring(close + 1) : '';
    if (after.startsWith(':')) port = int.tryParse(after.substring(1)) ?? 51820;
  } else {
    final lastColon = endpoint.lastIndexOf(':');
    if (lastColon > 0) {
      host = endpoint.substring(0, lastColon);
      port = int.tryParse(endpoint.substring(lastColon + 1)) ?? 51820;
    } else {
      host = endpoint;
    }
  }

  final localAddresses = (address.isNotEmpty ? address : '10.0.0.2')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map(ensureCidr)
      .toList();

  final allowed = (allowedIps.isNotEmpty ? allowedIps : '0.0.0.0/0, ::/0')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map(ensureCidr)
      .toList();

  String psk = '';
  if (presharedKey.isNotEmpty) {
    psk = normalizeWGKey(presharedKey) ?? presharedKey;
  }

  final peer = WireguardPeer(
    publicKey: normPub,
    preSharedKey: psk,
    endpointHost: host,
    endpointPort: port,
    allowedIps: allowed,
    persistentKeepalive: keepalive > 0 ? keepalive : null,
    reserved: reserved.isNotEmpty ? parseReserved(reserved) : null,
  );

  final label = nameHint?.trim().isNotEmpty == true ? nameHint!.trim() : 'WireGuard';
  final tag = tagFromLabel(label, 'wireguard', host, port);
  final awgObj = awg.isNotEmpty ? Awg(awg) : null;

  return WireguardSpec(
    id: newUuidV4(),
    tag: tag,
    label: label,
    server: host,
    port: port,
    rawUri: config,
    privateKey: normPriv,
    localAddresses: localAddresses,
    peers: [peer],
    mtu: mtu > 0 ? mtu : null,
    rawIni: config,
    awg: awgObj,
  );
}
