// Golden screenshots of the app shell, onboarding and secondary screens.
//
//   flutter test --update-goldens test/shell
//
// Platform channels don't exist here, so every provider that would touch the
// native runtime, secure storage or the network is replaced by a fake.

import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/ui/onboarding/welcome_page.dart';
import 'package:dsh_app/ui/remote/remote_screen.dart';
import 'package:dsh_app/ui/settings/settings_screen.dart';
import 'package:dsh_app/ui/shell/home_shell.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  goldenBoth('welcome', () => WelcomePage(onStart: () {}));

  goldenBoth(
    'drawer',
    () => HomeShell(chatBuilder: (_) => const _FakeChat(), initiallyOpen: true),
    overrides: () => [
      sessionsProvider.overrideWith(() => FakeSessions(sampleSessions())),
      currentSessionProvider.overrideWith(() => FakeCurrentSession('s2')),
    ],
  );

  goldenBoth(
    'settings',
    () => const SettingsScreen(),
    overrides: () => [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
  );

  goldenBoth('remote', () => const RemoteScreen());

  // The appearance group: the theme row (palette dot + name), chat text size.
  goldenBoth(
    'settings_appearance',
    () => const SettingsScreen(),
    overrides: () => [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
    before: (tester) async {
      await tester.scrollUntilVisible(find.text('对话字号'), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 260));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  // Large system text: the pickers move under their titles instead of wrapping.
  goldenBoth(
    'settings_appearance_large_text',
    () => MediaQuery.withClampedTextScaling(minScaleFactor: 1.6, maxScaleFactor: 1.6, child: const SettingsScreen()),
    overrides: () => [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
    before: (tester) async {
      await tester.scrollUntilVisible(find.text('对话字号'), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 260));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  // Below the fold of the settings page (about, licences).
  goldenBoth(
    'settings_bottom',
    () => const SettingsScreen(),
    overrides: () => [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
    before: (tester) async {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}

/// Stand-in for the chat screen behind the drawer: a few message shapes so the
/// glass has something to blur.
class _FakeChat extends StatelessWidget {
  const _FakeChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = DshSurfaces.of(context);
    Widget line(double width) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 220,
                height: 64,
                decoration: ShapeDecoration(color: surfaces.userBubble, shape: AppShape.bubble),
              ),
            ),
            const SizedBox(height: 24),
            line(320),
            line(300),
            line(340),
            line(180),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: ShapeDecoration(color: DshColors.of(context).codeWellBg, shape: AppShape.card),
            ),
            const SizedBox(height: 16),
            line(310),
            line(260),
          ],
        ),
      ),
    );
  }
}
