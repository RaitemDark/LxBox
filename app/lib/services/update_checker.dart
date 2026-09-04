import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_log.dart';
import 'project_links.dart';
import 'settings_storage.dart';

/// Light-weight GitHub Releases polling. Pings `/releases/latest` once a day
/// max, surfaces new versions via [latest] notifier. UI subscribes and shows
/// a SnackBar / About-section. No in-app APK install — opens release page in
/// browser, user downloads APK manually (standard sideload flow).
///
/// Spec: docs/spec/features/036 update check/spec.md
class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker I = UpdateChecker._();

  /// Latest release info, populated after [maybeCheck] / [forceCheck] success.
  /// Null until first successful check; null after dismiss (per spec — banner
  /// hides only for the dismissed tag, not forever).
  final ValueNotifier<UpdateInfo?> latest = ValueNotifier<UpdateInfo?>(null);

  /// Гидратирует [latest] из cached `last_known_version` (если он newer
  /// чем [localVersion] и не dismissed). Вызывается одноразово при старте,
  /// чтобы UI мгновенно показал известный апдейт без сетевого запроса.
  /// Dev builds (`X.Y.Z-dev.N`, `0.0.0-dev`) — это локальные сборки между
  /// тегами. Сравнивать их с release tag'ами бессмысленно: они всегда
  /// «younger» и UpdateChecker предложит «v1.8.3 available» сразу после
  /// `flutter run`. Skip для всех dev-версий — manual «Check now» из UI
  /// в любом случае работает.
  bool _isDevBuild(String version) =>
      version.contains('-dev') || version.startsWith('0.0.0');

  Future<void> hydrate({required String localVersion}) async {
    if (_isDevBuild(localVersion)) return;
    final tag = await SettingsStorage.getLastKnownVersion();
    if (tag.isEmpty) return;
    final dismissed = await SettingsStorage.getDismissedUpdateVersion();
    if (tag == dismissed) return;
    if (!isNewer(tag, localVersion)) return;
    latest.value = UpdateInfo(
      tag: tag,
      name: tag,
      htmlUrl: ProjectLinks.releaseTag(tag),
      publishedAt: null,
    );
  }

  /// Проверка с учётом throttle / toggle. Тихо пропускает если:
  /// - dev-build (`-dev.N`, `0.0.0-dev`)
  /// - `auto_check_updates` выключен
  /// - последний успешный check был < 24h назад
  /// - сеть недоступна / GitHub вернул не-200
  Future<void> maybeCheck({required String localVersion}) async {
    // Disabled: no GitHub mentions
    return;
  }

  Future<UpdateCheckResult> forceCheck({required String localVersion}) async {
    // Disabled: no GitHub mentions
    return UpdateCheckResult.skipped('Update check disabled');
  }

  /// Persist «не показывать этот релиз» + clear notifier. Read-guard
  /// (getDismissedUpdateVersion в update-snackbar) + writer wired: вызывается
  /// из «Later»-action диалога обновления (home_dialogs.dart, §092).
  Future<void> dismissCurrent() async {
    final cur = latest.value;
    if (cur == null) return;
    await SettingsStorage.setDismissedUpdateVersion(cur.tag);
    latest.value = null;
  }
}

/// Снаружи иммутабельный snapshot релиза. `publishedAt` null если из cache
/// (без сетевого fetch'а).
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.name,
    required this.htmlUrl,
    this.publishedAt,
  });

  final String tag;
  final String name;
  final String htmlUrl;
  final DateTime? publishedAt;
}

/// Outcome of a check — для UI кнопки "Check now" чтобы показать toast'ом.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.kind,
    this.info,
    this.localVersion,
    this.message,
    this.dismissed = false,
  });

  factory UpdateCheckResult.newer(UpdateInfo info, {required bool dismissed}) =>
      UpdateCheckResult._(
        kind: UpdateCheckKind.newer,
        info: info,
        dismissed: dismissed,
      );

  factory UpdateCheckResult.upToDate(String local) => UpdateCheckResult._(
        kind: UpdateCheckKind.upToDate,
        localVersion: local,
      );

  factory UpdateCheckResult.failed(String msg) => UpdateCheckResult._(
        kind: UpdateCheckKind.failed,
        message: msg,
      );

  factory UpdateCheckResult.skipped(String msg) => UpdateCheckResult._(
        kind: UpdateCheckKind.skipped,
        message: msg,
      );

  final UpdateCheckKind kind;
  final UpdateInfo? info;
  final String? localVersion;
  final String? message;
  final bool dismissed;
}

enum UpdateCheckKind { newer, upToDate, failed, skipped }

/// Pure semver compare — `vX.Y.Z` vs `X.Y.Z` (или с `v`-префиксом). Возвращает
/// `true` если remote строго newer, `false` иначе или при malformed input.
///
/// Поддерживает X.Y.Z и X.Y. Не поддерживает pre-release suffix'ы
/// (`-rc1`, `-beta`) — `/releases/latest` GitHub'а возвращает только stable,
/// так что в нормальном flow таких не бывает. Если всё-таки приходит — суффикс
/// игнорируется (`v1.4.3-dirty` парсится как `1.4.3`).
bool isNewer(String remote, String local) {
  final r = _parseSemver(remote);
  final l = _parseSemver(local);
  if (r == null || l == null) return false;
  for (var i = 0; i < 3; i++) {
    final ri = i < r.length ? r[i] : 0;
    final li = i < l.length ? l[i] : 0;
    if (ri > li) return true;
    if (ri < li) return false;
  }
  return false;
}

/// Парсит `vX.Y.Z` / `X.Y.Z` / `X.Y` в `[X, Y, Z]`. Возвращает null если
/// невалидно. Игнорирует suffix после первого не-числового / не-точечного
/// символа.
List<int>? _parseSemver(String raw) {
  if (raw.isEmpty) return null;
  var s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  // отрезаем суффикс типа "-dirty", "+build7", "-rc1"
  final cutAt = s.indexOf(RegExp(r'[^0-9.]'));
  if (cutAt >= 0) s = s.substring(0, cutAt);
  if (s.isEmpty) return null;
  final parts = s.split('.');
  if (parts.length < 2 || parts.length > 3) return null;
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    out.add(n);
  }
  return out;
}
