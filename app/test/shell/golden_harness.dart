// Shared setup for the shell golden tests: real fonts, fake providers, a phone-sized
// surface and a helper that renders one screen in light and dark.

import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/drawer_view_state.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/ui/common/side_insets.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fonts.dart';

// ── Fonts ────────────────────────────────────────────────────────────────────

/// Real fonts (see `test/support/test_fonts.dart`); `flutter_test_config.dart`
/// has already loaded them, so this returns at once.
Future<void> loadGoldenFonts() => loadTestFonts();

// ── Fakes ────────────────────────────────────────────────────────────────────

class FakeSettings extends SettingsController {
  FakeSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => state = state.copyWith(themeMode: mode);
}

class FakeSessions extends SessionsController {
  FakeSessions(this.sessions);

  final List<SessionSummary> sessions;

  @override
  Future<List<SessionSummary>> build() async => sessions;
}

class _GoldenHost extends ActiveHostController {
  @override
  HostRef build() => const HostRef.ssh('test-host');

  @override
  Future<void> get ready async {}
}

class FakeCurrentSession extends CurrentSessionController {
  FakeCurrentSession(this.initial);

  final String? initial;

  @override
  String? build() => initial;
}

// ── Sample data ──────────────────────────────────────────────────────────────

SessionSummary _session(String id, String title, DateTime at, {bool running = false}) => SessionSummary(
  sessionId: id,
  updatedAt: at,
  running: running,
  blank: false,
  agentAvailable: running,
  cwd: '/root/workspace',
  projections: SessionProjections(1, {'title': title}),
);

/// Today / yesterday / earlier, anchored to today's midnight so grouping is stable.
/// Noon on the latest Saturday: the drawer groups by calendar week (今天 /
/// 昨天 / 本周 / 更早), so goldens pin the day it thinks it is and the sample
/// dates hang off the same day; any weekday the tests run on looks the same.
final DateTime sampleNow = () {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: (today.weekday - DateTime.saturday) % 7)).add(const Duration(hours: 12));
}();

List<SessionSummary> sampleSessions() {
  final midnight = DateTime(sampleNow.year, sampleNow.month, sampleNow.day);
  return [
    _session('s1', '修复登录按钮重复提交', midnight.add(const Duration(seconds: 3)), running: true),
    _session('s2', '给设置页加深色模式', midnight.add(const Duration(seconds: 2))),
    _session('s3', '解释 proot 的 link2symlink', midnight.add(const Duration(seconds: 1))),
    _session('s4', '重构 sessions_state 的刷新逻辑', midnight.subtract(const Duration(hours: 3))),
    _session('s5', '写一个解析 tar.xz 的 Kotlin 工具', midnight.subtract(const Duration(hours: 9))),
    _session('s6', 'DeepSeek API 计费怎么算', midnight.subtract(const Duration(days: 3))),
    _session('s7', '把 README 翻译成英文', midnight.subtract(const Duration(days: 6))),
    _session('s8', '整理 Flutter 3.47 的新特性', midnight.subtract(const Duration(days: 12))),
  ];
}

// ── Rendering ────────────────────────────────────────────────────────────────

/// Phone surface: 390×844 logical at DPR 2, with Android-ish system bar insets.
void usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.padding = const FakeViewPadding(top: 32 * 2, bottom: 24 * 2);
  tester.view.viewPadding = const FakeViewPadding(top: 32 * 2, bottom: 24 * 2);
  addTearDown(tester.view.reset);
}

Widget goldenApp({
  required Widget home,
  required Brightness brightness,
  List<Override> overrides = const [],
  bool animations = false,
}) {
  return ProviderScope(
    overrides: [
      if (!overrides.any((override) => override.origin == activeHostProvider))
        activeHostProvider.overrideWith(_GoldenHost.new),
      if (!overrides.any((override) => override.origin == activeConnectionProvider))
        activeConnectionProvider.overrideWithValue(const AsyncData(null)),
      drawerClockProvider.overrideWithValue(() => sampleNow),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: withTestFonts(buildLightTheme()),
      darkTheme: withTestFonts(buildDarkTheme()),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Freeze breathing / spinning loops on a still frame.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !animations),
        // As the app's root does (lib/app.dart).
        child: MirroredSideInsets(child: child!),
      ),
      home: home,
    ),
  );
}

/// Renders [home] in light and dark and compares against `goldens/<name>_<mode>.png`.
void goldenBoth(
  String name,
  Widget Function() home, {
  List<Override> Function()? overrides,
  Future<void> Function(WidgetTester tester)? before,
}) {
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets('$name ($mode)', (tester) async {
      // Font loading is real async work; FakeAsync would never complete it.
      await tester.runAsync(loadGoldenFonts);
      usePhoneSurface(tester);
      await tester.pumpWidget(
        goldenApp(home: home(), brightness: brightness, overrides: overrides?.call() ?? const []),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      if (before != null) await before(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_$mode.png'));
    });
  }
}
