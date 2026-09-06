import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controllers/home_controller.dart';
import '../../../controllers/subscription_controller.dart';
import '../../../models/home_state.dart';
import '../../../services/crash_banner_state.dart';
import '../../../services/crash_share.dart';
import '../../../services/haptic_service.dart';
import '../home_dialogs.dart';
import '../home_menus.dart';
import '../node_list_presenter.dart';
import 'app_banner.dart';
import '../../../services/l10n/locale_controller.dart';

/// Controls-блок главного экрана.
///
/// Поведение байт-в-байт идентично оригиналу — изменена только вёрстка
/// (круглая кнопка подключения по центру + карточки вместо плоской строки),
/// под фирменный дизайн DARK. Все callback'и/условия доступности те же самые.
class HomeControls extends StatelessWidget {
  const HomeControls({
    super.key,
    required this.controller,
    required this.subController,
    required this.presenter,
    required this.connectingAnimChild,
    required this.state,
    required this.startActive,
    required this.startEnabled,
    required this.stopEnabled,
    required this.needsRestart,
    this.autoApplying = false,
    required this.errorTimerOnDismiss,
    required this.onStartWithAutoRefresh,
    required this.onRebuildAndClearDirty,
    required this.onRebuildAndReconnect,
    required this.onRebuildAndStart,
  });

  final HomeController controller;
  final SubscriptionController subController;
  final NodeListPresenter presenter;

  /// Готовый StatusChip (создаётся в State с доступом к `_connectingAnim`).
  final Widget connectingAnimChild;
  final HomeState state;
  final bool startActive;
  final bool startEnabled;
  final bool stopEnabled;
  final bool needsRestart;

  /// §338 — авто-применение в полёте (воронка пересборки при включённой
  /// галке): розовая плашка подавляется на окно rebuild+reload.
  final bool autoApplying;

  /// Cancel + clear lastError (раньше inline в `_buildControls`: отменял
  /// `_errorTimer` и звал `clearError`). Side-effect живёт в State.
  final VoidCallback errorTimerOnDismiss;

  final void Function() onStartWithAutoRefresh;
  final Future<void> Function() onRebuildAndClearDirty;
  final Future<void> Function() onRebuildAndReconnect;
  final Future<void> Function() onRebuildAndStart;

  /// §316 — отдать краш-репорт и погасить плашку. Штамп пишем в любом
  /// случае: пользователь плашку уже увидел, повторять на каждом запуске —
  /// навязчиво, даже если share сорвался (файл никуда не делся, он есть
  /// в Diagnostics → Crash reports).
  Future<void> _shareCrash() async {
    final report = CrashBannerState.I.pending;
    if (report == null) return;
    await shareCrashReport(report);
    await CrashBannerState.I.markShown();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isConnecting = state.tunnel == TunnelStatus.connecting;
    final isStopping = state.tunnel == TunnelStatus.stopping;
    final canToggle = !state.busy && !isConnecting && !isStopping;
    final toggleEnabled = canToggle && (state.tunnelUp || state.configRaw.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Круглая кнопка подключения по центру + статус-чип под ней ──
          // Логика onPressed идентична оригиналу (HapticService, confirmStop /
          // onStartWithAutoRefresh) — изменён только внешний вид кнопки.
          Stack(
            children: [
              Center(
                child: Column(
                  children: [
                    _buildRoundConnectButton(context, toggleEnabled, cs),
                    const SizedBox(height: 12),
                    connectingAnimChild,
                  ],
                ),
              ),
              // Кнопка reload — та же самая, что и раньше, просто теперь в
              // углу, а не в общей строке рядом с чипом.
              Align(
                alignment: Alignment.topRight,
                child: _buildReloadButton(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // §116 — единый banner-механизм: проекция состояния → BannerStack.
          // Три исторических плашки (settings_changed / restart / last_error)
          // + config_load_error деривятся в activeBanners.
          // §316 — плашка «ядро падало» приходит не из HomeState, а из
          // CrashBannerState (файловая система + storage-отметка), поэтому
          // подписка отдельная.
          AnimatedBuilder(
            animation: CrashBannerState.I,
            builder: (context, _) => BannerStack(
              banners: activeBanners(
                state,
                configDirty: subController.configDirty,
                busy: subController.busy,
                crashPending: CrashBannerState.I.pending != null,
                autoApplying: autoApplying, // §338
                actions: BannerActions(
                  onRebuild: () => unawaited(onRebuildAndClearDirty()),
                  // Не гасим restart на тап — если юзер отменит Stop-диалог,
                  // banner остаётся; гаснет реальным tunnel up↔down.
                  onConfirmStop: () =>
                      confirmStop(context, controller, controller.state),
                  onClearError: errorTimerOnDismiss,
                  onShareCrash: () => unawaited(_shareCrash()),
                  onDismissCrash: () =>
                      unawaited(CrashBannerState.I.markShown()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Направление + пинг — та же логика, оформлена карточкой ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text(getLocalText.s("Direction"),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: state.groups.contains(state.selectedGroup)
                          ? state.selectedGroup
                          : null,
                      hint: Text(getLocalText.s("Select direction")),
                      items: state.groups
                          .map((g) => DropdownMenuItem(
                              value: g, child: Text(state.groupLabelOf(g))))
                          .toList(),
                      onChanged: (!state.tunnelUp || state.busy || state.groups.isEmpty)
                          ? null
                          : (value) async {
                              controller.setSelectedGroup(value);
                              await controller.applyGroup(value);
                            },
                    ),
                  ),
                ),
                // §372 — InkWell, не GestureDetector: у последнего нет фокусного
                // узла, и на Android TV кнопка была недостижима с пульта
                // (D-pad её просто пропускал). InkWell фокусируется и
                // подсвечивается, поведение тапа/long-press то же.
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: (!state.tunnelUp || state.busy || state.nodes.isEmpty)
                      ? null
                      : () {
                          if (controller.massPingRunning) {
                            controller.cancelMassPing();
                          } else {
                            // §078 — пингуем в порядке отображения. Фильтр и
                            // sort учитываются: ping всё что **видно**, в том
                            // порядке как видно. Control-outbounds тоже в
                            // списке (clash.delay для них вернёт error или
                            // реальный latency для direct-out).
                            unawaited(controller.runMassUrltest(
                                order: presenter.computeDisplayList(state)));
                          }
                        },
                  onLongPress: () => showPingSettings(context, controller),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      controller.massPingRunning ? Icons.stop_circle_outlined : Icons.speed,
                      color: (!state.tunnelUp || state.busy || state.nodes.isEmpty)
                          ? Theme.of(context).disabledColor
                          : cs.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Круглая кнопка подключения со свечением — визуальный аналог оригинальной
  /// FilledButton.icon (Start/Stop). Логика onPressed идентична 1:1.
  Widget _buildRoundConnectButton(BuildContext context, bool toggleEnabled, ColorScheme cs) {
    final connected = state.tunnelUp;
    final ringColor = connected ? cs.primary : cs.outline;
    return Semantics(
      button: true,
      label: connected ? getLocalText.s("Stop") : getLocalText.s("Start"),
      child: SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (connected)
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.10),
                ),
              ),
            Material(
              color: cs.surface,
              shape: CircleBorder(
                side: BorderSide(color: ringColor.withValues(alpha: 0.6), width: 1.5),
              ),
              child: InkWell(
                // §372 — D-pad: на Android TV фокус при открытии экрана должен
                // стоять на главном действии, иначе первое нажатие пульта
                // уходит в никуда и выглядит как «кнопки не работают».
                autofocus: true,
                customBorder: const CircleBorder(),
                onTap: toggleEnabled
                    ? () {
                        HapticService.I.onConnectTap();
                        if (state.tunnelUp) {
                          confirmStop(context, controller, state);
                        } else {
                          onStartWithAutoRefresh();
                        }
                      }
                    : null,
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: 34,
                    color: toggleEnabled ? ringColor : cs.outline.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Кнопка reload (та же самая, что и раньше). Short tap = умный default
  /// (reconnect / rebuild+start / rebuild+reconnect), long press = меню с
  /// 3 явными действиями. Логика не изменена — только положение на экране.
  Widget _buildReloadButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dirty = subController.configDirty || needsRestart;
    final enabled = !state.busy && !subController.busy;
    final fg = dirty ? cs.onPrimaryContainer : null;
    final bg = dirty ? cs.primaryContainer : Colors.transparent;
    // Без Tooltip: на mobile он сам хватает long-press (его default trigger)
    // и наш `onLongPress` на InkWell никогда не срабатывает. Label доступен
    // через Semantics для accessibility.
    return Semantics(
      button: true,
      label: _defaultReloadLabel(state, dirty),
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        // Builder нужен чтобы `findRenderObject` в _showReloadMenu нашёл саму
        // кнопку, а не родительский Row/Column (иначе меню всплывёт с краю).
        child: Builder(builder: (inkCtx) => InkWell(
          onTap: enabled ? () => _runDefaultReload(state) : null,
          onLongPress: enabled ? () => _showReloadMenu(inkCtx, state) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.refresh, size: 20, color: fg),
          ),
        )),
      ),
    );
  }

  String _defaultReloadLabel(HomeState state, bool dirty) {
    if (!state.tunnelUp) return 'Rebuild config + connect';
    // §030: default tap теперь делает in-place reload (легче чем reconnect).
    // Long-press menu всё ещё даёт явный 'Reconnect' для full restart.
    return dirty ? 'Rebuild config + reconnect' : 'Reload';
  }

  void _runDefaultReload(HomeState state) {
    HapticService.I.onConnectTap();
    if (!state.tunnelUp) {
      unawaited(onRebuildAndStart());
      return;
    }
    final dirty = subController.configDirty || needsRestart;
    if (dirty) {
      unawaited(onRebuildAndReconnect());
    } else {
      // §030 — in-place reload через `commandServer.startOrReloadService`.
      // Раньше тут был `reconnect()` (full stop+start с recreate Android Service);
      // новый путь не убивает Service, tunnel дропается на ~3s вместо 5-10s.
      // Long-press menu даёт fallback на full reconnect для случаев когда
      // in-place reload не помог.
      unawaited(controller.reloadVpn());
    }
  }

  Future<void> _showReloadMenu(BuildContext anchorCtx, HomeState state) async {
    final box = anchorCtx.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(anchorCtx).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    final rect = RelativeRect.fromLTRB(
      pos.dx,
      pos.dy + size.height,
      overlay.size.width - pos.dx - size.width,
      overlay.size.height - pos.dy,
    );
    final reconnectLabel = state.tunnelUp ? 'Reconnect' : 'Connect';
    final rebuildReconnectLabel =
        state.tunnelUp ? 'Rebuild config + reconnect' : 'Rebuild config + connect';
    final choice = await showMenu<String>(
      context: anchorCtx,
      position: rect,
      items: [
        // Reload первый — самый light recovery (in-place через CommandServer.
        // startOrReloadService). Tap по кнопке выполняет это же действие.
        if (state.tunnelUp)
          PopupMenuItem(
            value: 'reload',
            child: Row(children: [
              const Icon(Icons.bolt, size: 18),
              const SizedBox(width: 12),
              Text(getLocalText.s("Reload")),
            ]),
          ),
        PopupMenuItem(
          value: 'reconnect',
          child: Row(children: [
            const Icon(Icons.sync, size: 18),
            const SizedBox(width: 12),
            Text(reconnectLabel),
          ]),
        ),
        PopupMenuItem(
          value: 'rebuild',
          child: Row(children: [
            const Icon(Icons.build_circle_outlined, size: 18),
            const SizedBox(width: 12),
            Text(getLocalText.s("Rebuild config only")),
          ]),
        ),
        PopupMenuItem(
          value: 'rebuild_reconnect',
          child: Row(children: [
            const Icon(Icons.refresh, size: 18),
            const SizedBox(width: 12),
            Text(rebuildReconnectLabel),
          ]),
        ),
      ],
    );
    if (!anchorCtx.mounted || choice == null) return;
    HapticService.I.onConnectTap();
    switch (choice) {
      case 'reload':
        unawaited(controller.reloadVpn());
      case 'reconnect':
        unawaited(controller.reconnect());
      case 'rebuild':
        unawaited(onRebuildAndClearDirty());
      case 'rebuild_reconnect':
        unawaited(onRebuildAndReconnect());
    }
  }
}
