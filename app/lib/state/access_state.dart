// Client system permissions for files, pets, background connectivity and voice.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pets/overlay_channel.dart';
import '../platform/platform_state.dart';
import '../platform/background_net.dart' show backgroundSettingsProvider;
import '../ui/chat/voice/voice_bridge.dart' show VoicePermission;
import 'notify_state.dart';
import 'voice_state.dart';

/// Client features that require system permissions.
enum AccessFeature { files, pet, background, voice }

/// System permissions in walk order: dialogs, settings, vendor pages, overlay.
enum AccessItem {
  mic,
  storage,
  notifications,
  battery,
  vendorBackground,
  autostart,
  overlay;

  /// A maker's own switch: no API reports it, so the person says it is set.
  bool get vendor => vendorWire != null;

  /// Its name for the native side (`VendorSettings.Switch`).
  String? get vendorWire => switch (this) {
    vendorBackground => 'background',
    autostart => 'autostart',
    _ => null,
  };

  /// Asked for with a system dialog: the answer is back when the call returns.
  bool get dialog => this == mic || this == storage || this == battery;
}

/// Where an item stands.
enum AccessState {
  /// Detected on.
  on,

  /// Detected off.
  off,

  /// A maker's switch the person went to and says is set ([AccessItem.vendor]).
  visited,

  /// A maker's switch not visited yet.
  unknown;

  /// Nothing left to do for it.
  bool get settled => this == on || this == visited;
}

/// The makers' own switches, by the native vendor key (`VendorSettings.kt`
/// holds their pages). Huawei and Honor keep start-up and background running
/// on one page; OPPO keeps everything on the app's details page; Samsung's
/// 「不受限制」 is the system's battery exemption.
const vendorSwitches = <String, List<AccessItem>>{
  'vivo': [AccessItem.vendorBackground, AccessItem.autostart],
  'xiaomi': [AccessItem.vendorBackground, AccessItem.autostart],
  'huawei': [AccessItem.vendorBackground],
  'honor': [AccessItem.vendorBackground],
  'oppo': [AccessItem.vendorBackground],
};

/// What [feature] needs on a phone of [vendor], in walk order.
List<AccessItem> accessItemsFor(AccessFeature feature, String? vendor) {
  final own = vendorSwitches[vendor] ?? const <AccessItem>[];
  final items = switch (feature) {
    AccessFeature.files => [AccessItem.storage],
    AccessFeature.pet => [AccessItem.overlay],
    AccessFeature.background => [
      AccessItem.notifications,
      AccessItem.battery,
      AccessItem.vendorBackground,
      AccessItem.autostart,
    ],
    AccessFeature.voice => [AccessItem.mic],
  };
  return [
    for (final item in AccessItem.values)
      if (items.contains(item) && (!item.vendor || own.contains(item))) item,
  ];
}

/// Everything [features] need, each item once, in walk order.
List<AccessItem> accessWalk(Iterable<AccessFeature> features, String? vendor) {
  final wanted = {for (final f in features) ...accessItemsFor(f, vendor)};
  return [
    for (final item in AccessItem.values)
      if (wanted.contains(item)) item,
  ];
}

/// What the phone says right now. A null grant: this phone can't tell (no
/// native side), and the item isn't offered.
class AccessReadings {
  const AccessReadings({
    this.vendor,
    this.appLabel,
    this.mic,
    this.storage,
    this.notifications,
    this.battery,
    this.overlay,
    this.overlayBlocked = false,
    this.sdk,
    this.metered,
  });

  /// `vivo`, `xiaomi`, `huawei`, `honor`, `oppo`, `samsung`; null for the rest.
  final String? vendor;

  /// The app's name as system settings list it.
  final String? appLabel;
  final bool? mic;
  final bool? storage;
  final bool? notifications;
  final bool? battery;

  /// The pet can be drawn over other apps.
  final bool? overlay;

  /// The system says the overlay is allowed but the window was refused: a
  /// maker's own floating-window switch (vivo), on the app's details page.
  final bool overlayBlocked;

  final int? sdk;

  /// On mobile data (a download costs the person).
  final bool? metered;

  bool? granted(AccessItem item) => switch (item) {
    AccessItem.mic => mic,
    AccessItem.storage => storage,
    AccessItem.notifications => notifications,
    AccessItem.battery => battery,
    AccessItem.overlay => overlay,
    AccessItem.vendorBackground || AccessItem.autostart => null,
  };
}

/// [item]'s state from [readings]; null when this phone can't tell (the
/// item is left out). A maker's switch is [AccessState.visited] once the
/// person said so, whatever the phone.
AccessState? accessStateOf(AccessItem item, AccessReadings readings, Set<AccessItem> visited) {
  if (item.vendor) return visited.contains(item) ? AccessState.visited : AccessState.unknown;
  return switch (readings.granted(item)) {
    true => AccessState.on,
    false => AccessState.off,
    null => null,
  };
}

// ── Reading and opening ─────────────────────────────────────────────────────

/// Reads every item and opens where each is turned on.
abstract class AccessDriver {
  Future<AccessReadings> read();

  /// The system dialog for [item], else its settings page; [again] after a
  /// denial goes to the page a dialog can no longer be raised from. False
  /// when nothing opened.
  Future<bool> open(AccessItem item, {bool again = false});

  /// This app's system info page (「允许受限制的设置」).
  Future<bool> openAppInfo();
}

/// The real phone: the same channels the features use.
class SystemAccessDriver implements AccessDriver {
  SystemAccessDriver(this.ref);

  final Ref ref;

  static const _voice = MethodChannel('dsh/voice');

  static Future<T?> _safe<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      // No native side (tests, desktop), or it failed: unknown.
      return null;
    }
  }

  @override
  Future<AccessReadings> read() async {
    final bridge = ref.read(clientPlatformProvider);
    final pet = ref.read(petOverlayProvider.notifier);
    final info = _safe(() => ref.read(backgroundSettingsProvider.future));
    final mic = _safe(
      () async => switch (await _voice.invokeMethod<String>('permission')) {
        'granted' => true,
        'denied' => false,
        _ => null,
      },
    );
    final storage = _safe(() async => (await bridge.storageStatus()).granted);
    final notify = _safe(() async {
      final s = await ref.read(notifyChannelProvider).status();
      return s.native ? s.enabled : null;
    });
    final battery = _safe(bridge.batteryExempt);
    final metered = _safe(bridge.networkMetered);
    final overlay = _safe(pet.refresh);
    final petStatus = await overlay;
    final settings = await info;
    // Keep the pages that show the same facts in step.
    ref.invalidate(batteryExemptProvider);
    ref.invalidate(notifySystemStatusProvider);
    return AccessReadings(
      vendor: settings?.vendor,
      appLabel: settings?.label,
      mic: await mic,
      storage: await storage,
      notifications: await notify,
      battery: await battery,
      overlay: petStatus == null || !petStatus.native ? null : petStatus.permission.usable,
      overlayBlocked: petStatus?.permission == PetOverlayPermission.blocked,
      sdk: petStatus?.sdk == 0 ? null : petStatus?.sdk,
      metered: await metered,
    );
  }

  @override
  Future<bool> open(AccessItem item, {bool again = false}) async {
    final bridge = ref.read(clientPlatformProvider);
    final opened = await _safe<bool>(() async {
      switch (item) {
        case AccessItem.mic:
          final voice = ref.read(voiceBridgeProvider);
          // Denied for good: only the app's permission page can turn it on.
          if (await voice.requestPermission() == VoicePermission.blocked) await voice.openSettings();
          return true;
        case AccessItem.storage:
          final access = await bridge.requestStorage();
          if (access.granted) return true;
          // The device ignores legacy storage: 「所有文件访问」 is the way.
          if (access.permission && !access.legacy) return bridge.openAllFilesAccess();
          // Denied again: the dialog won't come back, the app's page will.
          if (again) return bridge.openAppDetails();
          return true;
        case AccessItem.notifications:
          return ref.read(notifyChannelProvider).openSettings();
        case AccessItem.battery:
          return await bridge.requestBatteryExempt() ?? false;
        case AccessItem.vendorBackground || AccessItem.autostart:
          return await bridge.openVendorSettings(item.vendorWire!) != null;
        case AccessItem.overlay:
          // On with it: the pet is what the permission is for. A vivo switch the
          // system doesn't report opens the app's page instead.
          await ref.read(petOverlayProvider.notifier).turnOn();
          return true;
      }
    });
    return opened ?? false;
  }

  @override
  Future<bool> openAppInfo() async => await _safe(ref.read(clientPlatformProvider).openAppDetails) ?? false;
}

final accessDriverProvider = Provider<AccessDriver>((ref) => SystemAccessDriver(ref));

/// The latest readings; [AccessReadingsController.refresh] reads again (on
/// coming back from system settings).
final accessReadingsProvider = AsyncNotifierProvider<AccessReadingsController, AccessReadings>(
  AccessReadingsController.new,
);

class AccessReadingsController extends AsyncNotifier<AccessReadings> {
  @override
  Future<AccessReadings> build() => ref.read(accessDriverProvider).read();

  /// Reads again, keeping the last readings on screen meanwhile.
  Future<AccessReadings> refresh() async {
    final readings = await ref.read(accessDriverProvider).read();
    if (ref.mounted) state = AsyncData(readings);
    return readings;
  }
}

/// The makers' switches the person went to and said are set: no API reports
/// them, so this is the only record (`system_access_visited`).
final accessVisitedProvider = NotifierProvider<AccessVisitedController, Set<AccessItem>>(AccessVisitedController.new);

class AccessVisitedController extends Notifier<Set<AccessItem>> {
  static const prefsKey = 'system_access_visited';

  @override
  Set<AccessItem> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = prefs.getStringList(prefsKey) ?? const [];
      if (!ref.mounted) return;
      state = {...state, for (final n in names) ?AccessItem.values.asNameMap()[n]};
    } catch (_) {}
  }

  Future<void> mark(AccessItem item) async {
    if (state.contains(item)) return;
    state = {...state, item};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, [for (final i in state) i.name]);
    } catch (_) {}
  }
}
