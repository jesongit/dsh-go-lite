import 'package:dsh_app/state/access_state.dart';
import 'package:dsh_app/ui/access/access_walk.dart';
import 'package:dsh_app/ui/settings/system_access_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/golden_harness.dart';
import 'support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('permission settings retain client features and omit phone control', (tester) async {
    final driver = FakeAccessDriver(offPhone);
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(home: const SystemAccessPage(), brightness: Brightness.light, overrides: accessOverrides(driver)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access-section-files')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-section-pet')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-section-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-section-voice')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-section-phone')), findsNothing);
  });

  testWidgets('microphone permission completes only after the native reading confirms it', (tester) async {
    var done = false;
    final driver = FakeAccessDriver(offPhone, answer: (item, r) => readingsWith(r, mic: true));
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(
        home: AccessWalk(items: const [AccessItem.mic], onDone: () => done = true),
        brightness: Brightness.light,
        overrides: accessOverrides(driver),
      ),
    );
    await tester.pumpAndSettle();
    expect(done, isFalse);
    await tester.tap(find.byKey(const ValueKey('access-primary')));
    await tester.pumpAndSettle();
    expect(driver.opened, ['mic']);
    expect(done, isTrue);
  });
}
