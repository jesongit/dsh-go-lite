import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Preferences of this client. Remote provider credentials belong to the host.
/// Legacy local engine preferences and secure keys are left untouched on disk.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.webPhoneLayout = true,
    this.hardwareEnterSends = false,
    this.chatTextScale = 1.0,
    this.foldCompletedTurns = true,
    this.visualReplies = true,
    this.loaded = false,
  });

  final ThemeMode themeMode;
  final bool webPhoneLayout;
  final bool hardwareEnterSends;
  final double chatTextScale;
  final bool foldCompletedTurns;
  final bool visualReplies;
  final bool loaded;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? webPhoneLayout,
    bool? hardwareEnterSends,
    double? chatTextScale,
    bool? foldCompletedTurns,
    bool? visualReplies,
    bool? loaded,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    webPhoneLayout: webPhoneLayout ?? this.webPhoneLayout,
    hardwareEnterSends: hardwareEnterSends ?? this.hardwareEnterSends,
    chatTextScale: chatTextScale ?? this.chatTextScale,
    foldCompletedTurns: foldCompletedTurns ?? this.foldCompletedTurns,
    visualReplies: visualReplies ?? this.visualReplies,
    loaded: loaded ?? this.loaded,
  );
}

List<(double, String)> get chatTextScales => [
  (0.9, appL10n.stateSizeSmall),
  (1.0, appL10n.stateSizeStandard),
  (1.15, appL10n.stateSizeLarge),
  (1.3, appL10n.stateSizeExtraLarge),
];

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _webPhoneLayoutKey = 'web_phone_layout';
  static const _hardwareEnterKey = 'hardware_enter_sends';
  static const _chatTextScaleKey = 'chat_text_scale';
  static const _foldTurnsKey = 'fold_completed_turns';
  static const _visualRepliesKey = 'visual_replies';
  late Future<void> _loaded;

  @override
  AppSettings build() {
    _loaded = _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == prefs.getString(_themeKey),
          orElse: () => ThemeMode.system,
        ),
        webPhoneLayout: prefs.getBool(_webPhoneLayoutKey) ?? true,
        hardwareEnterSends: prefs.getBool(_hardwareEnterKey) ?? false,
        chatTextScale: _knownScale(prefs.getDouble(_chatTextScaleKey)),
        foldCompletedTurns: prefs.getBool(_foldTurnsKey) ?? true,
        visualReplies: prefs.getBool(_visualRepliesKey) ?? true,
        loaded: true,
      );
    } catch (_) {
      if (ref.mounted) state = const AppSettings(loaded: true);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(themeMode: mode);
    await (await SharedPreferences.getInstance()).setString(_themeKey, mode.name);
  }

  static double _knownScale(double? value) => chatTextScales.any((s) => s.$1 == value) ? value! : 1.0;

  Future<void> setChatTextScale(double value) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(chatTextScale: value);
    await (await SharedPreferences.getInstance()).setDouble(_chatTextScaleKey, value);
  }

  Future<void> setFoldCompletedTurns(bool value) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(foldCompletedTurns: value);
    await (await SharedPreferences.getInstance()).setBool(_foldTurnsKey, value);
  }

  Future<void> setVisualReplies(bool value) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(visualReplies: value);
    await (await SharedPreferences.getInstance()).setBool(_visualRepliesKey, value);
  }

  Future<void> setWebPhoneLayout(bool value) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(webPhoneLayout: value);
    await (await SharedPreferences.getInstance()).setBool(_webPhoneLayoutKey, value);
  }

  Future<void> setHardwareEnterSends(bool value) async {
    await _loaded;
    if (!ref.mounted) return;
    state = state.copyWith(hardwareEnterSends: value);
    await (await SharedPreferences.getInstance()).setBool(_hardwareEnterKey, value);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
