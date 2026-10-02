import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../../models/node_spec.dart';
import 'uri_parsers.dart';
import 'uri_utils.dart';

Object? getYamlProp(Map proxy, String key) {
  if (proxy.containsKey(key)) return proxy[key];
  final merge = proxy['<<'];
  if (merge is Map && merge.containsKey(key)) {
    return merge[key];
  }
  return null;
}

/// §Clash — Конвертер параметров proxies из Clash YAML формата в `List<NodeSpec>`
List<NodeSpec> convertClashYamlToNodes(String yamlText) {
  try {
    final doc = loadYaml(yamlText);
    if (doc is! Map) return const [];
    
    final rawProxies = <dynamic>[];
    
    // 1. Прямые прокси в `proxies:`
    final directProxies = getYamlProp(doc, 'proxies');
    if (directProxies is List) {
      rawProxies.addAll(directProxies);
    }
    
    // 2. Провайдеры в `proxy-providers:` (например, warp-local с payload:)
    final providersMap = getYamlProp(doc, 'proxy-providers');
    if (providersMap is Map) {
      for (final p in providersMap.values) {
        if (p is Map) {
          final payload = getYamlProp(p, 'payload');
          if (payload is List) {
            rawProxies.addAll(payload);
          }
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
  final name = getYamlProp(proxy, 'name')?.toString() ?? 'Proxy';
  final type = getYamlProp(proxy, 'type')?.toString().toLowerCase() ?? '';
  final server = getYamlProp(proxy, 'server')?.toString() ?? '';
  final portStr = getYamlProp(proxy, 'port')?.toString() ?? '';
  final port = int.tryParse(portStr) ?? 443;

  if (server.isEmpty || portStr.isEmpty) return null;

  switch (type) {
    case 'masque':
      final privKey = getYamlProp(proxy, 'private-key')?.toString() ?? '';
      final pubKey = getYamlProp(proxy, 'public-key')?.toString() ?? '';
      final ip = getYamlProp(proxy, 'ip')?.toString() ?? '';
      final ipv6 = getYamlProp(proxy, 'ipv6')?.toString() ?? '';
      final address = [ip, ipv6].where((e) => e.isNotEmpty).join(',');
      final localAddresses = address
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map(ensureCidr)
          .toList();
      final vhttp = getYamlProp(proxy, 'network')?.toString() ?? getYamlProp(proxy, 'vhttp')?.toString() ?? 'h2';
      final sni = getYamlProp(proxy, 'sni')?.toString() ?? '';
      final mtu = int.tryParse(getYamlProp(proxy, 'mtu')?.toString() ?? '') ?? 1280;

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
      final uuid = getYamlProp(proxy, 'uuid')?.toString() ?? '';
      if (uuid.isEmpty) return null;
      final network = getYamlProp(proxy, 'network')?.toString() ?? 'tcp';
      final tls = getYamlProp(proxy, 'tls') == true;
      final realityOpts = getYamlProp(proxy, 'reality-opts');
      final reality = realityOpts is Map;
      final security = reality ? 'reality' : (tls ? 'tls' : 'none');
      final sni = getYamlProp(proxy, 'servername')?.toString() ?? getYamlProp(proxy, 'sni')?.toString() ?? '';
      
      final queryParams = <String, String>{
        'type': network,
        'security': security,
      };
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      
      final wsOpts = getYamlProp(proxy, 'ws-opts');
      if (wsOpts is Map && wsOpts['path'] != null) {
        queryParams['path'] = wsOpts['path'].toString();
      }
      final grpcOpts = getYamlProp(proxy, 'grpc-opts');
      if (grpcOpts is Map && grpcOpts['grpc-service-name'] != null) {
        queryParams['serviceName'] = grpcOpts['grpc-service-name'].toString();
      }
      if (reality) {
        final ro = realityOpts as Map;
        if (ro['public-key'] != null) queryParams['pbk'] = ro['public-key'].toString();
        if (ro['short-id'] != null) queryParams['sid'] = ro['short-id'].toString();
      }

      final query = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final uri = 'vless://$uuid@$server:$port?$query#${Uri.encodeComponent(name)}';
      return parseUri(uri);

    case 'vmess':
      final uuid = getYamlProp(proxy, 'uuid')?.toString() ?? '';
      if (uuid.isEmpty) return null;
      final network = getYamlProp(proxy, 'network')?.toString() ?? 'tcp';
      final tls = getYamlProp(proxy, 'tls') == true;
      final sni = getYamlProp(proxy, 'servername')?.toString() ?? getYamlProp(proxy, 'sni')?.toString() ?? '';
      
      var path = '';
      final wsOpts = getYamlProp(proxy, 'ws-opts');
      if (wsOpts is Map && wsOpts['path'] != null) {
        path = wsOpts['path'].toString();
      }

      final vmessMap = {
        'v': '2',
        'ps': name,
        'add': server,
        'port': portStr,
        'id': uuid,
        'aid': getYamlProp(proxy, 'alterId')?.toString() ?? '0',
        'net': network,
        'type': 'none',
        'host': sni,
        'path': path,
        'tls': tls ? 'tls' : '',
        'sni': sni,
      };
      final b64 = base64.encode(utf8.encode(jsonEncode(vmessMap)));
      return parseUri('vmess://$b64');

    case 'trojan':
      final password = getYamlProp(proxy, 'password')?.toString() ?? getYamlProp(proxy, 'uuid')?.toString() ?? '';
      if (password.isEmpty) return null;
      final network = getYamlProp(proxy, 'network')?.toString() ?? 'tcp';
      final sni = getYamlProp(proxy, 'servername')?.toString() ?? getYamlProp(proxy, 'sni')?.toString() ?? '';
      final queryParams = <String, String>{
        'type': network,
        'security': 'tls',
      };
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      final query = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      return parseUri('trojan://$password@$server:$port?$query#${Uri.encodeComponent(name)}');

    case 'ss':
    case 'shadowsocks':
      final cipher = getYamlProp(proxy, 'cipher')?.toString() ?? '';
      final password = getYamlProp(proxy, 'password')?.toString() ?? '';
      if (cipher.isEmpty || password.isEmpty) return null;
      final userpass = base64.encode(utf8.encode('$cipher:$password'));
      return parseUri('ss://$userpass@$server:$port#${Uri.encodeComponent(name)}');

    case 'hysteria2':
    case 'hy2':
    case 'hysteria':
      final password = getYamlProp(proxy, 'password')?.toString() ?? getYamlProp(proxy, 'auth')?.toString() ?? '';
      final sni = getYamlProp(proxy, 'sni')?.toString() ?? getYamlProp(proxy, 'servername')?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      final obfs = getYamlProp(proxy, 'obfs');
      if (obfs != null) queryParams['obfs'] = obfs.toString();
      final obfsPass = getYamlProp(proxy, 'obfs-password');
      if (obfsPass != null) queryParams['obfs-password'] = obfsPass.toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return parseUri('hysteria2://$password@$server:$port$query#${Uri.encodeComponent(name)}');

    case 'tuic':
      final uuid = getYamlProp(proxy, 'uuid')?.toString() ?? '';
      final password = getYamlProp(proxy, 'password')?.toString() ?? '';
      final token = uuid.isNotEmpty ? '$uuid:$password' : password;
      final sni = getYamlProp(proxy, 'sni')?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      final cc = getYamlProp(proxy, 'congestion-controller');
      if (cc != null) queryParams['congestion_control'] = cc.toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return parseUri('tuic://$token@$server:$port$query#${Uri.encodeComponent(name)}');

    case 'wireguard':
    case 'wg':
      final secretKey = getYamlProp(proxy, 'private-key')?.toString() ?? '';
      final publicKey = getYamlProp(proxy, 'public-key')?.toString() ?? '';
      final ip = getYamlProp(proxy, 'ip')?.toString() ?? getYamlProp(proxy, 'ipv6')?.toString() ?? '10.0.0.2';
      final presharedKey = getYamlProp(proxy, 'preshared-key')?.toString() ?? '';
      final mtu = int.tryParse(getYamlProp(proxy, 'mtu')?.toString() ?? '') ?? 1420;
      final reserved = getYamlProp(proxy, 'reserved');

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
