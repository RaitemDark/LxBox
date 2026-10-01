import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../../models/node_spec.dart';
import 'uri_utils.dart';

/// §Clash — Конвертер параметров proxies из Clash YAML формата в `List<NodeSpec>`
List<NodeSpec> convertClashYamlToNodes(String yamlText) {
  try {
    final doc = loadYaml(yamlText);
    if (doc is! Map) return const [];
    
    final rawProxies = <dynamic>[];
    
    // 1. Прямые прокси в `proxies:`
    if (doc['proxies'] is List) {
      rawProxies.addAll(doc['proxies'] as List);
    }
    
    // 2. Провайдеры в `proxy-providers:` (например, warp-local с payload:)
    if (doc['proxy-providers'] is Map) {
      final providers = doc['proxy-providers'] as Map;
      for (final p in providers.values) {
        if (p is Map && p['payload'] is List) {
          rawProxies.addAll(p['payload'] as List);
        }
      }
    }

    final nodes = <NodeSpec>[];
    for (final raw in rawProxies) {
      if (raw is! Map) continue;
      final node = clashProxyToNode(raw);
      if (node != null) {
        nodes.add(node);
      }
    }
    return nodes;
  } catch (_) {
    return const [];
  }
}

NodeSpec? clashProxyToNode(Map proxy) {
  final name = proxy['name']?.toString() ?? 'Proxy';
  final type = proxy['type']?.toString().toLowerCase() ?? '';
  final server = proxy['server']?.toString() ?? '';
  final portStr = proxy['port']?.toString() ?? '';
  final port = int.tryParse(portStr) ?? 443;

  if (server.isEmpty || portStr.isEmpty) return null;

  switch (type) {
    case 'masque':
      final privKey = proxy['private-key']?.toString() ?? '';
      final pubKey = proxy['public-key']?.toString() ?? '';
      final ip = proxy['ip']?.toString() ?? '';
      final ipv6 = proxy['ipv6']?.toString() ?? '';
      final address = [ip, ipv6].where((e) => e.isNotEmpty).join(',');
      final localAddresses = address
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map(ensureCidr)
          .toList();
      final vhttp = proxy['network']?.toString() ?? proxy['vhttp']?.toString() ?? 'h2';
      final sni = proxy['sni']?.toString() ?? '';
      final mtu = int.tryParse(proxy['mtu']?.toString() ?? '') ?? 1280;

      if (privKey.isEmpty || pubKey.isEmpty || localAddresses.isEmpty) return null;

      final tag = tagFromLabel(name, 'masque', server, port);

      return MasqueSpec(
        id: newUuidV4(),
        tag: tag,
        label: name,
        server: server,
        port: port,
        rawUri: '',
        privateKeyDer: privKey,
        publicKeyDer: pubKey,
        localAddresses: localAddresses,
        vhttp: vhttp,
        sni: sni,
        mtu: mtu,
      );

    case 'vless':
      final uuid = proxy['uuid']?.toString() ?? '';
      if (uuid.isEmpty) return null;
      final network = proxy['network']?.toString() ?? 'tcp';
      final tls = proxy['tls'] == true;
      final reality = proxy['reality-opts'] is Map;
      final security = reality ? 'reality' : (tls ? 'tls' : 'none');
      final sni = proxy['servername']?.toString() ?? proxy['sni']?.toString() ?? '';
      
      final queryParams = <String, String>{
        'type': network,
        'security': security,
      };
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      
      final wsOpts = proxy['ws-opts'];
      if (wsOpts is Map && wsOpts['path'] != null) {
        queryParams['path'] = wsOpts['path'].toString();
      }
      final grpcOpts = proxy['grpc-opts'];
      if (grpcOpts is Map && grpcOpts['grpc-service-name'] != null) {
        queryParams['serviceName'] = grpcOpts['grpc-service-name'].toString();
      }
      if (reality) {
        final ro = proxy['reality-opts'] as Map;
        if (ro['public-key'] != null) queryParams['pbk'] = ro['public-key'].toString();
        if (ro['short-id'] != null) queryParams['sid'] = ro['short-id'].toString();
      }

      final query = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final uri = 'vless://$uuid@$server:$port?$query#${Uri.encodeComponent(name)}';
      return parseVlessUri(uri);

    case 'vmess':
      final uuid = proxy['uuid']?.toString() ?? '';
      if (uuid.isEmpty) return null;
      final network = proxy['network']?.toString() ?? 'tcp';
      final tls = proxy['tls'] == true;
      final sni = proxy['servername']?.toString() ?? proxy['sni']?.toString() ?? '';
      
      var path = '';
      final wsOpts = proxy['ws-opts'];
      if (wsOpts is Map && wsOpts['path'] != null) {
        path = wsOpts['path'].toString();
      }

      final vmessMap = {
        'v': '2',
        'ps': name,
        'add': server,
        'port': portStr,
        'id': uuid,
        'aid': proxy['alterId']?.toString() ?? '0',
        'net': network,
        'type': 'none',
        'host': sni,
        'path': path,
        'tls': tls ? 'tls' : '',
        'sni': sni,
      };
      final b64 = base64.encode(utf8.encode(jsonEncode(vmessMap)));
      return parseVmessUri('vmess://$b64');

    case 'trojan':
      final password = proxy['password']?.toString() ?? proxy['uuid']?.toString() ?? '';
      if (password.isEmpty) return null;
      final network = proxy['network']?.toString() ?? 'tcp';
      final sni = proxy['servername']?.toString() ?? proxy['sni']?.toString() ?? '';
      final queryParams = <String, String>{
        'type': network,
        'security': 'tls',
      };
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      final query = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      return parseTrojanUri('trojan://$password@$server:$port?$query#${Uri.encodeComponent(name)}');

    case 'ss':
    case 'shadowsocks':
      final cipher = proxy['cipher']?.toString() ?? '';
      final password = proxy['password']?.toString() ?? '';
      if (cipher.isEmpty || password.isEmpty) return null;
      final userpass = base64.encode(utf8.encode('$cipher:$password'));
      return parseShadowsocksUri('ss://$userpass@$server:$port#${Uri.encodeComponent(name)}');

    case 'hysteria2':
    case 'hy2':
    case 'hysteria':
      final password = proxy['password']?.toString() ?? proxy['auth']?.toString() ?? '';
      final sni = proxy['sni']?.toString() ?? proxy['servername']?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      if (proxy['obfs'] != null) queryParams['obfs'] = proxy['obfs'].toString();
      if (proxy['obfs-password'] != null) queryParams['obfs-password'] = proxy['obfs-password'].toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return parseHysteria2Uri('hysteria2://$password@$server:$port$query#${Uri.encodeComponent(name)}');

    case 'tuic':
      final uuid = proxy['uuid']?.toString() ?? '';
      final password = proxy['password']?.toString() ?? '';
      final token = uuid.isNotEmpty ? '$uuid:$password' : password;
      final sni = proxy['sni']?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      if (proxy['congestion-controller'] != null) queryParams['congestion_control'] = proxy['congestion-controller'].toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return parseTuicUri('tuic://$token@$server:$port$query#${Uri.encodeComponent(name)}');

    case 'wireguard':
    case 'wg':
      final secretKey = proxy['private-key']?.toString() ?? '';
      final publicKey = proxy['public-key']?.toString() ?? '';
      final ip = proxy['ip']?.toString() ?? proxy['ipv6']?.toString() ?? '10.0.0.2';
      final presharedKey = proxy['preshared-key']?.toString() ?? '';
      final mtu = int.tryParse(proxy['mtu']?.toString() ?? '') ?? 1420;
      final reserved = proxy['reserved'];

      if (secretKey.isEmpty || publicKey.isEmpty) return null;

      final normPriv = normalizeWGKey(secretKey) ?? secretKey;
      final normPub = normalizeWGKey(publicKey) ?? publicKey;

      final localAddresses = [ip]
          .where((e) => e.isNotEmpty)
          .map(ensureCidr)
          .toList();

      final peer = WireguardPeer(
        publicKey: normPub,
        preSharedKey: presharedKey.isNotEmpty ? (normalizeWGKey(presharedKey) ?? presharedKey) : '',
        endpointHost: server,
        endpointPort: port,
        allowedIps: const ['0.0.0.0/0', '::/0'],
        reserved: reserved is List ? parseReserved(reserved.join(',')) : null,
      );

      final tag = tagFromLabel(name, 'wireguard', server, port);

      return WireguardSpec(
        id: newUuidV4(),
        tag: tag,
        label: name,
        server: server,
        port: port,
        rawUri: '',
        privateKey: normPriv,
        localAddresses: localAddresses,
        peers: [peer],
        mtu: mtu,
      );

    default:
      return null;
  }
}
