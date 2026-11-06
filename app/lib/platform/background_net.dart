// Some phone makers cut an app's network as soon as it
// leaves the screen, foreground service or not (vivo until 「允许后台高耗电」 is
// on). Remote connections also need background network access for updates.
// This decides when to say so: one quiet line in the chat on the way back,
// leading to 后台保活 (ui/notify/background_net_host.dart draws it).

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../state/connection_state.dart';
import '../state/notify_state.dart' show launchNoticeShownProvider;
import 'client_platform.dart';
import 'platform_state.dart';

/// Why the line shows.
enum BackgroundNetReason {
  /// After the first finished turn, on a phone whose maker holds background apps back: once.
  intro;

  String get text => switch (this) {
    intro => appL10n.stateBackgroundFinish,
  };
}

/// The decisions, without timers, storage or the platform (unit-tested).
abstract final class BackgroundNetPolicy {
  /// Per reason: the first time and once more, until the app is let run in the background.
  static const maxShows = 2;

  /// Makers that hold background apps back out of the box.
  static const strictVendors = {'vivo', 'xiaomi', 'huawei', 'honor', 'oppo'};

  /// The one-time intro after a finished turn.
  static bool introDue({
    required bool introduced,
    required String? vendor,
    required bool? exempt,
    required Map<BackgroundNetReason, int> shown,
  }) => !introduced && strictVendors.contains(vendor) && exempt == false && shown.values.every((n) => n == 0);
}

/// The line to show now, or null. The host feeds it app visibility; the person dismisses it.
class BackgroundNetController extends Notifier<BackgroundNetReason?> {
  static const _shownKey = 'background_net.shown.';
  static const _introKey = 'background_net.intro';

  final Map<BackgroundNetReason, int> _shown = {};
  bool _introduced = false;
  Future<void>? _loading;
  bool _visible = true;
  final Set<String> _running = {};
  StreamSubscription<HostEvent>? _events;

  ClientPlatform get _bridge => ref.read(clientPlatformProvider);

  @override
  BackgroundNetReason? build() {
    _loading ??= _load();
    // A turn ends on the active host: when to introduce 后台保活.
    ref.listen(activeHostEventsProvider, (_, next) => _follow(next), fireImmediately: true);
    ref.onDispose(() => unawaited(_events?.cancel()));
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final reason in BackgroundNetReason.values) {
        _shown[reason] = prefs.getInt('$_shownKey${reason.name}') ?? 0;
      }
      _introduced = prefs.getBool(_introKey) ?? false;
    } catch (_) {
      // No storage (tests without a mock): start from nothing.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final MapEntry(:key, :value) in _shown.entries) {
        await prefs.setInt('$_shownKey${key.name}', value);
      }
      await prefs.setBool(_introKey, _introduced);
    } catch (_) {}
  }

  void _follow(Stream<HostEvent>? events) {
    unawaited(_events?.cancel());
    _events = null;
    _running.clear();
    if (events == null) return;
    _events = events.listen((event) {
      if (event is! SessionStatusEvent) return;
      if (event.running) {
        _running.add(event.sessionId);
      } else if (_running.remove(event.sessionId)) {
        unawaited(_onTurnEnded());
      }
    });
  }

  /// The app left the screen ([visible] false) or came back.
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
  }

  Future<bool?> _exempt() async {
    final exempt = await _bridge.batteryExempt();
    if (exempt == true && _shown.values.any((n) => n > 0)) {
      // Let run in the background: a later revoke may bring the line back.
      _shown.updateAll((_, _) => 0);
      unawaited(_save());
    }
    return exempt;
  }

  Future<void> _onTurnEnded() async {
    await _loading;
    if (_introduced || !_visible || state != null) return;
    final vendor = (await ref.read(backgroundSettingsProvider.future))?.vendor;
    final due = BackgroundNetPolicy.introDue(
      introduced: _introduced,
      vendor: vendor,
      exempt: await _exempt(),
      shown: _shown,
    );
    if (!due || !ref.mounted || !_visible) return;
    _show(BackgroundNetReason.intro);
  }

  void _show(BackgroundNetReason reason) {
    _shown[reason] = (_shown[reason] ?? 0) + 1;
    // Any line about background running counts as the introduction.
    _introduced = true;
    unawaited(_save());
    ref.read(launchNoticeShownProvider.notifier).set(true);
    state = reason;
  }

  /// Tapped away, or 去放行 was tapped.
  void dismiss() => state = null;
}

/// The active host's `$events` (turn ends for the intro); null while it is not connected.
final activeHostEventsProvider = Provider<Stream<HostEvent>?>(
  (ref) => ref.watch(activeConnectionProvider.select((c) => c.value?.client))?.hostEvents,
);

/// The phone maker and the app's name in system settings; null without the native side.
final backgroundSettingsProvider = FutureProvider<BackgroundSettingsInfo?>(
  (ref) => ref.watch(clientPlatformProvider).backgroundSettings(),
);

final backgroundNetProvider = NotifierProvider<BackgroundNetController, BackgroundNetReason?>(
  BackgroundNetController.new,
);
