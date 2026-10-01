import 'dart:convert';
import 'package:yaml/yaml.dart';

/// §Clash — Конвертер параметров proxies из Clash YAML формата в канонические URIs
List<String> convertClashYamlToUris(String yamlText) {
  try {
    final doc = loadYaml(yamlText);
    if (doc is! Map) return const [];
    final proxies = doc['proxies'];
    if (proxies is! List) return const [];

    final uris = <String>[];
    for (final raw in proxies) {
      if (raw is! Map) continue;
      final uri = clashProxyToUri(raw);
      if (uri != null && uri.isNotEmpty) {
        uris.add(uri);
      }
    }
    return uris;
  } catch (_) {
    return const [];
  }
}

String? clashProxyToUri(Map proxy) {
  final name = proxy['name']?.toString() ?? 'Proxy';
  final type = proxy['type']?.toString().toLowerCase() ?? '';
  final server = proxy['server']?.toString() ?? '';
  final port = proxy['port']?.toString() ?? '';

  if (server.isEmpty || port.isEmpty) return null;

  switch (type) {
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
      return 'vless://$uuid@$server:$port?$query#${Uri.encodeComponent(name)}';

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
        'port': port,
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
      return 'vmess://$b64';

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
      return 'trojan://$password@$server:$port?$query#${Uri.encodeComponent(name)}';

    case 'ss':
    case 'shadowsocks':
      final cipher = proxy['cipher']?.toString() ?? '';
      final password = proxy['password']?.toString() ?? '';
      if (cipher.isEmpty || password.isEmpty) return null;
      final userpass = base64.encode(utf8.encode('$cipher:$password'));
      return 'ss://$userpass@$server:$port#${Uri.encodeComponent(name)}';

    case 'hysteria2':
    case 'hy2':
      final password = proxy['password']?.toString() ?? proxy['auth']?.toString() ?? '';
      final sni = proxy['sni']?.toString() ?? proxy['servername']?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      if (proxy['obfs'] != null) queryParams['obfs'] = proxy['obfs'].toString();
      if (proxy['obfs-password'] != null) queryParams['obfs-password'] = proxy['obfs-password'].toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return 'hysteria2://$password@$server:$port$query#${Uri.encodeComponent(name)}';

    case 'tuic':
      final uuid = proxy['uuid']?.toString() ?? '';
      final password = proxy['password']?.toString() ?? '';
      final token = uuid.isNotEmpty ? '$uuid:$password' : password;
      final sni = proxy['sni']?.toString() ?? '';
      final queryParams = <String, String>{};
      if (sni.isNotEmpty) queryParams['sni'] = sni;
      if (proxy['congestion-controller'] != null) queryParams['congestion_control'] = proxy['congestion-controller'].toString();
      final query = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      return 'tuic://$token@$server:$port$query#${Uri.encodeComponent(name)}';

    default:
      return null;
  }
}
