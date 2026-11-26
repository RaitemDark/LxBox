import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_log.dart';

class RealIpInfo {
  final String ip;
  final String countryCode;
  final String countryName;
  final String flagEmoji;
  final String isp;

  const RealIpInfo({
    required this.ip,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.isp,
  });

  static String countryCodeToEmoji(String code) {
    if (code.length != 2) return '🌐';
    final int first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

class RealIpLookupService {
  static RealIpInfo? _cachedInfo;
  static RealIpInfo? get cachedInfo => _cachedInfo;

  static Future<RealIpInfo?> lookupRealIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final ip = data['ip']?.toString() ?? '';
          final code = data['country_code']?.toString().toUpperCase() ?? '';
          final country = data['country']?.toString() ?? '';
          final isp = (data['connection']?['isp'] ?? data['isp'])?.toString() ?? '';
          final emoji = RealIpInfo.countryCodeToEmoji(code);
          _cachedInfo = RealIpInfo(
            ip: ip,
            countryCode: code,
            countryName: country,
            flagEmoji: emoji,
            isp: isp,
          );
          return _cachedInfo;
        }
      }
    } catch (e) {
      AppLog.I.warning('RealIpLookup failed: $e');
    }
    return null;
  }
}
