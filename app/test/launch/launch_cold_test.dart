// Cold launches preserve the custom media round; the default overlay leaves when the client is ready.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dsh_app/launch/custom_launch.dart';
import 'package:dsh_app/launch/launch_media.dart';
import 'package:dsh_app/launch/launch_motion.dart';
import 'package:dsh_app/launch/launch_state.dart';
import 'package:dsh_app/ui/launch/launch_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

/// A custom picture that ends its round when the test says so.
class _Clip extends LaunchMedia {
  VoidCallback? onDone;
  bool started = false;

  @override
  Size get size => const Size(90, 160);

  @override
  Widget view() => const ColoredBox(color: Color(0xFF2E5C8A));

  @override
  void play({VoidCallback? onDone}) {
    started = true;
    this.onDone = onDone;
  }

  void finish() => onDone?.call();
}

const _custom = CustomLaunch(kind: LaunchMediaKind.video, path: '/clip.mp4', width: 90, height: 160);

void main() {
  late FakeLaunchChannel channel;
  setUp(() => channel = FakeLaunchChannel());

  /// Android 8–11 (no system splash to wait for): the motion starts with the first frame.
  Future<LaunchController> start(
    WidgetTester tester, {
    bool reduceMotion = false,
    CustomLaunch? custom,
    bool systemSplash = false,
  }) async {
    usePhone(tester);
    final ui.Image icon = (await tester.runAsync(() => flatImage(320, 320, const Color(0xFF4F68B7))))!;
    final c = LaunchController(
      snapshot: snapshotFor(icon: icon, sdk: systemSplash ? 35 : 30, systemSplash: systemSplash),
      custom: custom,
      channel: channel,
    );
    await tester.pumpWidget(launchApp(c, reduceMotion: reduceMotion));
    await tester.pump();
    return c;
  }

  /// Advances [ms] in 20 ms frames, so animations and timers land in order.
  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  test('begin accepts an active client snapshot without engine state', () async {
    final snapshot = await LaunchSnapshot.fromMap({'active': true, 'sdk': 35, 'iconPx': 420, 'background': 0xFFEBF1FE});
    expect(snapshot, isNotNull);
    expect(snapshot!.sdk, 35);
    expect(snapshot.iconPx, 420);
    expect(await LaunchSnapshot.fromMap({'active': false}), isNull);
  });

  group('cold start', () {
    testWidgets('default motion leaves as soon as the client is ready', (tester) async {
      final c = await start(tester);
      await wait(tester, 200);
      expect(c.phase, LaunchPhase.playing);
      c.ready();
      await tester.pump();
      expect(c.holds, isFalse);
      expect(c.phase, LaunchPhase.leaving);
      expect(channel.marks, containsAllInOrder(['firstFrame', 'ready']));
      await wait(tester, LaunchMotion.leave.inMilliseconds + 40);
      expect(c.phase, LaunchPhase.gone);
    });

    testWidgets('Android 12+ hands over the splash before showing the ready client', (tester) async {
      final c = await start(tester, systemSplash: true);
      c.ready();
      await wait(tester, 100);
      expect(c.phase, LaunchPhase.cover);
      await c.handOver(const Rect.fromLTWH(115, 342, 160, 160), removed: true);
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('custom: one round, then goes', (tester) async {
      final c = await start(tester, custom: _custom);
      final clip = _Clip();
      c.useMedia(clip);
      await tester.pump();
      expect(clip.started, isTrue);
      c.ready();
      await wait(tester, 1500);
      expect(c.phase, LaunchPhase.playing);
      clip.finish();
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('custom: as long as it is, no cap after client readiness', (tester) async {
      final c = await start(tester, custom: _custom);
      final clip = _Clip();
      c.useMedia(clip);
      await tester.pump();
      c.ready();
      await wait(tester, 400);
      await tester.pump();
      // A 10 s clip: still there at 9.9 s.
      await wait(tester, 9500);
      expect(c.phase, LaunchPhase.playing);
      clip.finish();
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('custom still opening: waits for media, then its whole round', (tester) async {
      final c = await start(tester, custom: _custom);
      c.ready();
      await wait(tester, 400);
      await wait(tester, 400);
      expect(c.phase, LaunchPhase.playing);
      final clip = _Clip();
      c.useMedia(clip);
      await tester.pump();
      expect(clip.started, isTrue);
      await wait(tester, 3000);
      expect(c.phase, LaunchPhase.playing);
      clip.finish();
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('custom that can\'t be read: the default motion\'s rules', (tester) async {
      // A clip without its poster doesn't open.
      final c = await start(tester, custom: _custom);
      c.ready();
      await wait(tester, 200);
      expect(c.phase, LaunchPhase.playing);
      await c.openMedia(const Size(780, 1688));
      await tester.pump();
      expect(c.mediaFailed, isTrue);
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('a tap skips it: custom', (tester) async {
      final c = await start(tester, custom: _custom);
      c.useMedia(_Clip());
      await tester.pump();
      c.ready();
      await wait(tester, 1000);
      expect(c.phase, LaunchPhase.playing);
      await tester.tap(find.byKey(LaunchOverlay.skipKey));
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
      expect(channel.marks, contains('skipped'));
    });

    testWidgets('a tap skips it: the default motion, even before the app is ready', (tester) async {
      final c = await start(tester);
      await wait(tester, 300);
      await tester.tap(find.byKey(LaunchOverlay.skipKey));
      await tester.pump();
      expect(c.phase, LaunchPhase.leaving);
      await wait(tester, LaunchMotion.leave.inMilliseconds + 40);
      expect(c.phase, LaunchPhase.gone);
    });

    testWidgets('a custom still stays as long as the default motion', (tester) async {
      final c = await start(tester, custom: _custom);
      final ui.Image still = (await tester.runAsync(() => flatImage(90, 160, const Color(0xFF2E5C8A))))!;
      c.useMedia(StillLaunchMedia(still));
      c.ready();
      await wait(tester, 1300);
      expect(c.phase, LaunchPhase.playing);
      await wait(tester, 100);
      expect(c.phase, LaunchPhase.leaving);
    });
  });

  group('custom playback', () {
    /// A 5 s clip, the app ready 200 ms in: the layer stays until the clip ends, then goes.
    Future<void> wholeRound(WidgetTester tester, LaunchController c) async {
      final clip = _Clip();
      c.useMedia(clip);
      await tester.pump();
      expect(clip.started, isTrue);
      await wait(tester, 200);
      c.ready();
      await tester.pump();
      expect(c.holds, isTrue);
      await wait(tester, 4600);
      expect(c.phase, LaunchPhase.playing);
      expect(find.byType(CustomLaunchView), findsOneWidget);
      clip.finish();
      await tester.pump();
      // A light phone: straight onto the app, no fade.
      expect(c.phase, isIn([LaunchPhase.leaving, LaunchPhase.gone]));
    }

    testWidgets('the client ready: its whole round', (tester) async {
      await wholeRound(tester, await start(tester, custom: _custom));
    });

    testWidgets('a light phone (the app\'s own 减少动画, not the system\'s): its whole round', (tester) async {
      await wholeRound(tester, await start(tester, reduceMotion: true, custom: _custom));
    });

    testWidgets('Android 12+: waits for the splash, then its whole round', (tester) async {
      final c = await start(tester, systemSplash: true, custom: _custom);
      c.ready();
      await wait(tester, 300);
      expect(c.phase, LaunchPhase.cover);
      await c.handOver(null, removed: true);
      await tester.pump();
      await wholeRound(tester, c);
    });

    testWidgets('a tap skips it', (tester) async {
      final c = await start(tester, reduceMotion: true, custom: _custom);
      c.useMedia(_Clip());
      await tester.pump();
      c.ready();
      await wait(tester, 1000);
      expect(c.phase, LaunchPhase.playing);
      await tester.tap(find.byKey(LaunchOverlay.skipKey));
      await tester.pump();
      expect(c.phase, isIn([LaunchPhase.leaving, LaunchPhase.gone]));
      expect(channel.marks, contains('skipped'));
    });
  });

  group('no waiting', () {
    test('a warm start of the app (its process still there): no launch screen, a custom one set or not', () async {
      final dir = Directory.systemTemp.createTempSync('launch_warm');
      addTearDown(() => dir.deleteSync(recursive: true));
      final clip = File('${dir.path}/clip.mp4')..writeAsBytesSync([0]);
      SharedPreferences.setMockInitialValues({
        CustomLaunch.prefsKey: jsonEncode(
          CustomLaunch(kind: LaunchMediaKind.video, path: clip.path, width: 90, height: 160).toJson(),
        ),
      });
      expect(await CustomLaunch.load(), isNotNull);
      final warm = FakeLaunchChannel(answer: {'active': false});
      expect(await LaunchController.begin(channel: warm), isNull);
      expect(LaunchController.active.value, isNull);
    });

    testWidgets('系统的减少动画 with a custom picture: its first frame, not played, not waited for', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final c = await start(tester, reduceMotion: true, custom: _custom);
      final clip = _Clip();
      c.useMedia(clip);
      await tester.pump();
      expect(clip.started, isFalse);
      c.ready();
      await tester.pump();
      expect(c.phase, LaunchPhase.gone);
    });

    testWidgets('default motion goes the moment the app is ready', (tester) async {
      final c = await start(tester);
      await wait(tester, 200);
      c.ready();
      await tester.pump();
      expect(c.holds, isFalse);
      expect(c.phase, LaunchPhase.leaving);
    });

    testWidgets('a light phone keeps the default motion to its first frame: gone the moment the app is ready', (
      tester,
    ) async {
      final c = await start(tester, reduceMotion: true);
      await wait(tester, 200);
      expect(find.byKey(LaunchMark.wordmarkKey), findsNothing);
      c.ready();
      await tester.pump();
      expect(c.phase, LaunchPhase.gone);
    });

    testWidgets('减少动画 on a cold start: nothing plays, nothing is waited for', (tester) async {
      final c = await start(tester, reduceMotion: true);
      await tester.pump();
      expect(c.reduced, isTrue);
      await wait(tester, 100);
      c.ready();
      await tester.pump();
      expect(c.phase, LaunchPhase.gone);
    });

    testWidgets('减少动画 arriving late releases the default overlay when the client is ready', (tester) async {
      usePhone(tester);
      final ui.Image icon = (await tester.runAsync(() => flatImage(320, 320, const Color(0xFF4F68B7))))!;
      final c = LaunchController(
        snapshot: snapshotFor(icon: icon, sdk: 30, systemSplash: false),
        channel: channel,
      );
      await tester.pumpWidget(launchApp(c));
      await tester.pump();
      await wait(tester, 200);
      expect(c.phase, LaunchPhase.playing);
      await tester.pumpWidget(launchApp(c, reduceMotion: true));
      c.ready();
      await tester.pump();
      await tester.pump();
      expect(c.phase, isIn([LaunchPhase.leaving, LaunchPhase.gone]));
    });
  });
}
