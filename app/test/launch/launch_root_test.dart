// 启动画面 at the app root: RootGate says "ready" the frame its first page is up (no waiting
// for the engine), and the layer over the app comes and goes without the page under it losing
// its state.

import 'package:dsh_app/app.dart';
import 'package:dsh_app/launch/launch_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/ui/launch/launch_overlay.dart';
import 'package:dsh_app/ui/shell/root_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/golden_harness.dart';
import 'support.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => setState(() => taps++), child: Text('taps $taps')),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LaunchController.active.value = null);

  testWidgets('RootGate: ready as soon as client preferences and home are up', (tester) async {
    final channel = FakeLaunchChannel();
    final c = LaunchController(snapshot: snapshotFor(), channel: channel);
    LaunchController.active.value = c;
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(
        home: const RootGate(home: Scaffold(body: Text('home'))),
        brightness: Brightness.light,
        overrides: [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(channel.marks, contains('ready'));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the app root: the layer over everything, then gone; the page keeps its state', (tester) async {
    usePhone(tester);
    final c = LaunchController(snapshot: snapshotFor(sdk: 30, systemSplash: false), channel: FakeLaunchChannel());
    LaunchController.active.value = c;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true)))],
        child: const DshApp(home: _Counter()),
      ),
    );
    await tester.pump();
    expect(find.byType(LaunchOverlay), findsOneWidget);
    expect(c.phase, LaunchPhase.playing);
    // A tap skips the launch screen, and doesn't reach the page under it.
    await tester.tap(find.text('taps 0'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('taps 0'), findsOneWidget);
    expect(c.phase, LaunchPhase.leaving);
    c.ready();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.phase, LaunchPhase.gone);
    expect(find.byType(LaunchOverlay), findsNothing);
    expect(LaunchController.active.value, isNull);
    await tester.tap(find.text('taps 0'));
    await tester.pump();
    expect(find.text('taps 1'), findsOneWidget);
  });
}
