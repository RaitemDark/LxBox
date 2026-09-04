// -----------------------------------------------------------------------------
// §141 P2.4e — централизованные имена MethodChannel / EventChannel.
//
// Раньше строки каналов (`com.leadaxe.dark/methods` и т.д.) дублировались в
// 6+ Dart-файлах + Kotlin-стороне. Опечатка в одном месте → молчаливо мёртвый
// канал (вызовы уходят в никуда). Единый источник здесь; Kotlin-зеркало —
// `MainActivity.kt` / `VpnPlugin.kt` (их строки должны совпадать дословно).
//
// Прецедент стиля: `box_vpn_client/method_names.dart` (`_Methods`).
// -----------------------------------------------------------------------------

class PlatformChannels {
  const PlatformChannels._();

  /// §324 — он же package name приложения: `OverrideOptions.includePackage`
  /// native кладёт именно его (`service.packageName` в `buildOverrideOptions`),
  /// и зеркало override сравнивает по этой строке. Публичный, чтобы литерал не
  /// расползался третьей копией.
  static const packageName = 'com.leadaxe.dark';

  static const _ns = packageName;

  /// Основной двусторонний канал: config/VPN lifecycle/notification/system-proxy
  /// и пр. (`VpnPlugin.kt handleMethodCall`).
  static const methods = '$_ns/methods';

  /// EventChannel статусов туннеля (broadcast от native → `onStatusChanged`).
  static const statusEvents = '$_ns/status_events';

  /// Утилитарный канал (url_launcher, showToast и пр.).
  static const utils = '$_ns/utils';

  /// Wi-Fi history: MethodChannel + native `onWifiSeen` events (§051).
  static const wifiHistory = '$_ns/wifi_history';

  /// EventChannel для forward'а sing-box core-логов в AppLog (§043).
  /// Отдельный (короткий) неймспейс — зеркало `BoxService.coreLog`.
  static const coreLog = 'dark/coreLog';

  /// §122 Фаза 0 — EventChannel'ы нативного CommandClient-канала.
  /// Зеркало `VpnPlugin.CC_*_CHANNEL` + `BoxVpnService.cc*Sink`.
  /// status: скорость/память/трафик (always-on). outbounds: плоский node-list +
  /// delay. groups: дерево групп. connections: снапшот соединений (дельты→аккумулятор).
  static const ccStatus = 'dark/cc/status';
  static const ccOutbounds = 'dark/cc/outbounds';
  static const ccGroups = 'dark/cc/groups';
  static const ccConnections = 'dark/cc/connections';
  static const ccDns = 'dark/cc/dns'; // §180 — DNS-журнал из ядра (SPEC 018)
}
