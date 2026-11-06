// Client shell formatters, update sheet spacing and small-screen layout.

import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/state/update_state.dart';
import 'package:dsh_app/ui/chat/render/markdown_body.dart';
import 'package:dsh_app/ui/common/app_sheet.dart';
import 'package:dsh_app/ui/onboarding/welcome_page.dart';
import 'package:dsh_app/ui/remote/remote_screen.dart';
import 'package:dsh_app/ui/settings/settings_screen.dart';
import 'package:dsh_app/ui/shell/home_shell.dart';
import 'package:dsh_app/ui/shell/sessions_drawer.dart';
import 'package:dsh_app/ui/update/update_sheet.dart';
import 'package:dsh_app/update/release.dart';
import 'package:dsh_app/update/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  group('formatters', () {
    test('sessions group by local calendar day', () {
      final now = DateTime(2026, 10, 23, 9);
      expect(sessionDayOf(DateTime(2026, 10, 23, 0, 1), now), SessionDay.today);
      expect(sessionDayOf(DateTime(2026, 10, 22, 23, 59), now), SessionDay.yesterday);
      // 23 Oct 2026 is a Friday; the week starts on Monday the 19th.
      expect(sessionDayOf(DateTime(2026, 10, 20), now), SessionDay.thisWeek);
      expect(sessionDayOf(DateTime(2026, 10, 19, 0, 1), now), SessionDay.thisWeek);
      expect(sessionDayOf(DateTime(2026, 10, 18, 23, 59), now), SessionDay.earlier);
      // On a Monday, Sunday is 昨天 and nothing is 本周 before it.
      final monday = DateTime(2026, 10, 19, 9);
      expect(sessionDayOf(DateTime(2026, 10, 18, 12), monday), SessionDay.yesterday);
      expect(sessionDayOf(DateTime(2026, 10, 17, 12), monday), SessionDay.earlier);
    });
  });

  testWidgets('update notes begin 16 inside the card', (tester) async {
    usePhoneSurface(tester);
    final release = ReleaseInfo(
      version: AppVersion.tryParse('1.2.0+2')!,
      tag: 'v1.2.0',
      notes: '修复了连接恢复',
      apks: {ApkFlavor.arm64: ReleaseAsset(name: 'app.apk', url: Uri.parse('https://example.com/app.apk'), size: 1234)},
    );
    await tester.pumpWidget(
      goldenApp(
        home: const Scaffold(body: SafeArea(child: UpdateSheet())),
        brightness: Brightness.light,
        overrides: [
          appUpdateProvider.overrideWith(
            () => _FixedUpdate(
              AppUpdateState(
                loaded: true,
                current: AppVersion.tryParse('1.0.0+1')!,
                flavor: ApkFlavor.arm64,
                check: UpdateCheckPhase.available,
                latest: release,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    final notes = tester.getRect(find.byType(MarkdownBody));
    final card = tester.getRect(find.byType(SheetGroup));
    expect(notes.left - card.left, closeTo(16, .5));
    expect(card.right - notes.right, closeTo(16, .5));
    expect(tester.takeException(), isNull);
  });

  group('small screen, large text: nothing overflows', () {
    final screens = <String, Widget Function()>{
      'welcome': () => WelcomePage(onStart: () {}),
      'settings': () => const SettingsScreen(),
      'remote': () => const RemoteScreen(),
      'drawer': () => HomeShell(chatBuilder: (_) => const SizedBox.expand(), initiallyOpen: true),
    };
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets(name, (tester) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(320 * 2, 568 * 2);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          goldenApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: build(),
              ),
            ),
            brightness: Brightness.light,
            overrides: [
              settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true))),
              sessionsProvider.overrideWith(() => FakeSessions(sampleSessions())),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
    }
  });
}

class _FixedUpdate extends AppUpdateController {
  _FixedUpdate(this.initial);

  final AppUpdateState initial;

  @override
  AppUpdateState build() => initial;
}
