// The quiet line about background running (lib/platform/background_net.dart,
// lib/ui/notify/background_net_host.dart): when it shows, how often, where it
// sits, and what its two taps do.
//
//   flutter test --update-goldens test/notify/background_net_test.dart

import 'dart:async';

import 'package:dsh_app/platform/background_net.dart';
import 'package:dsh_app/platform/client_platform.dart';
import 'package:dsh_app/platform/platform_state.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/ui/chat/chat_header.dart';
import 'package:dsh_app/ui/notify/background_net_host.dart';
import 'package:dsh_app/ui/settings/background_guide_page.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/golden_harness.dart' as shell;
import 'support.dart';

class _Bridge extends ClientPlatform {
  bool? exempt = false;
  String? vendor = 'vivo';

  @override
  Future<bool?> batteryExempt() async => exempt;

  @override
  Future<BackgroundSettingsInfo?> backgroundSettings() async => BackgroundSettingsInfo(vendor: vendor, label: 'DSH');

  @override
  Future<String?> openBackgroundSettings() async => 'vendor';
}

class _Fixed extends BackgroundNetController {
  _Fixed(this.initial);

  final BackgroundNetReason? initial;

  @override
  BackgroundNetReason? build() => initial;
}

void main() {
  group('policy', () {
    const none = <BackgroundNetReason, int>{};

    test('intro only on strict makers, not exempt, nothing shown yet', () {
      bool due({
        bool introduced = false,
        String? vendor = 'vivo',
        bool? exempt = false,
        Map<BackgroundNetReason, int> shown = none,
      }) => BackgroundNetPolicy.introDue(introduced: introduced, vendor: vendor, exempt: exempt, shown: shown);
      expect(due(), isTrue);
      expect(due(vendor: 'xiaomi'), isTrue);
      expect(due(vendor: 'samsung'), isFalse);
      expect(due(vendor: null), isFalse);
      expect(due(exempt: true), isFalse);
      expect(due(introduced: true), isFalse);
      expect(due(shown: {BackgroundNetReason.intro: 1}), isFalse);
    });
  });

  group('controller', () {
    late _Bridge bridge;
    late StreamController<HostEvent> events;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          clientPlatformProvider.overrideWithValue(bridge),
          activeHostEventsProvider.overrideWithValue(events.stream),
          activeConnectionProvider.overrideWithValue(const AsyncData(null)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(backgroundNetProvider, (_, _) {});
      return c;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      bridge = _Bridge();
      events = StreamController<HostEvent>.broadcast(sync: true);
    });

    test('returning without a finished turn says nothing', () async {
      final c = container();
      await settle();
      final net = c.read(backgroundNetProvider.notifier);
      net.setVisible(false);
      net.setVisible(true);
      await settle();
      expect(c.read(backgroundNetProvider), isNull);
    });

    test('first finished turn on a strict maker: the intro, once', () async {
      final c = container();
      await settle();
      events
        ..add(const SessionStatusEvent('s1', true))
        ..add(const SessionStatusEvent('s1', false));
      await settle();
      expect(c.read(backgroundNetProvider), BackgroundNetReason.intro);
      c.read(backgroundNetProvider.notifier).dismiss();
      events
        ..add(const SessionStatusEvent('s1', true))
        ..add(const SessionStatusEvent('s1', false));
      await settle();
      expect(c.read(backgroundNetProvider), isNull);
      expect((await SharedPreferences.getInstance()).getBool('background_net.intro'), isTrue);
    });

    test('no intro on other makers', () async {
      bridge.vendor = 'samsung';
      final c = container();
      await settle();
      events
        ..add(const SessionStatusEvent('s1', true))
        ..add(const SessionStatusEvent('s1', false));
      await settle();
      expect(c.read(backgroundNetProvider), isNull);
    });

    test('no intro for a turn that ended while the app was away', () async {
      final c = container();
      await settle();
      final net = c.read(backgroundNetProvider.notifier);
      events.add(const SessionStatusEvent('s2', true));
      net.setVisible(false);
      events.add(const SessionStatusEvent('s2', false));
      await settle();
      expect(c.read(backgroundNetProvider), isNull);
    });
  });

  group('pill', () {
    Widget app(Widget child, {double textScale = 1}) => MaterialApp(
      theme: buildLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    for (final scale in [1.0, 1.3]) {
      testWidgets('glyph and action sit 12 from their ends, centred (text ×$scale)', (tester) async {
        await tester.pumpWidget(
          app(
            BackgroundNetPill(reason: BackgroundNetReason.intro, onDismiss: () {}, onOpen: () {}),
            textScale: scale,
          ),
        );
        final pill = tester.getRect(find.byType(GlassSurface));
        final glyph = tester.getRect(find.byKey(const ValueKey('background-net-glyph')));
        final action = tester.getRect(find.byKey(const ValueKey('background-net-action')));
        final text = tester.getRect(find.text('在后台保持远程连接和提醒'));
        expect(glyph.left - pill.left, moreOrLessEquals(12, epsilon: 0.01));
        expect(pill.right - action.right, moreOrLessEquals(12, epsilon: 0.01));
        for (final part in [glyph, action, text]) {
          expect(part.center.dy, moreOrLessEquals(pill.center.dy, epsilon: 0.5));
        }
        expect(pill.height, greaterThanOrEqualTo(BackgroundNetPill.minHeight));
        // One line: the label never wraps under the glyph.
        expect(text.height, lessThan(pill.height));
      });
    }

    testWidgets('a tap dismisses; 去放行 opens 后台保活', (tester) async {
      var dismissed = 0;
      var opened = 0;
      await tester.pumpWidget(
        app(BackgroundNetPill(reason: BackgroundNetReason.intro, onDismiss: () => dismissed++, onOpen: () => opened++)),
      );
      await tester.tap(find.text('在后台保持远程连接和提醒'));
      expect((dismissed, opened), (1, 0));
      await tester.tap(find.text('去放行'));
      expect((dismissed, opened), (1, 1));
    });
  });

  group('host', () {
    Widget app(BackgroundNetReason? reason) => ProviderScope(
      overrides: [
        backgroundNetProvider.overrideWith(() => _Fixed(reason)),
        batteryExemptProvider.overrideWith((ref) async => false),
        backgroundSettingsProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: BackgroundNetHost()),
      ),
    );

    testWidgets('under the chat header; a tap anywhere on it clears it', (tester) async {
      shell.usePhoneSurface(tester);
      await tester.pumpWidget(app(BackgroundNetReason.intro));
      await tester.pumpAndSettle();
      final pill = tester.getRect(find.byType(BackgroundNetPill));
      final context = tester.element(find.byType(BackgroundNetPill));
      expect(pill.top, moreOrLessEquals(ChatHeader.heightOf(context), epsilon: 0.01));
      expect(pill.center.dx, moreOrLessEquals(390 / 2, epsilon: 0.01));
      await tester.tap(find.byType(BackgroundNetPill));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundNetPill), findsNothing);
    });

    testWidgets('去放行 opens 后台保活 and the line is gone on the way back', (tester) async {
      shell.usePhoneSurface(tester);
      await tester.pumpWidget(app(BackgroundNetReason.intro));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去放行'));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundGuidePage), findsOneWidget);
      expect(find.byType(BackgroundNetPill), findsNothing);
      Navigator.of(tester.element(find.byType(BackgroundGuidePage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundNetPill), findsNothing);
    });

    testWidgets('waits while a page covers the chat', (tester) async {
      shell.usePhoneSurface(tester);
      await tester.pumpWidget(app(BackgroundNetReason.intro));
      await tester.pumpAndSettle();
      expect(find.text('在后台保持远程连接和提醒'), findsOneWidget);
      Navigator.of(tester.element(find.byType(BackgroundNetHost)))
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('设置'))));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundNetPill), findsNothing);
      Navigator.of(tester.element(find.text('设置'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('在后台保持远程连接和提醒'), findsOneWidget);
    });
  });

  group('golden', () {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      for (final reason in [BackgroundNetReason.intro]) {
        testWidgets('${reason.name} ($mode)', (tester) async {
          await tester.runAsync(shell.loadGoldenFonts);
          shell.usePhoneSurface(tester);
          await tester.pumpWidget(
            shell.goldenApp(
              home: const AppBackdrop(
                child: Scaffold(backgroundColor: Colors.transparent, body: BackgroundNetHost()),
              ),
              brightness: brightness,
              overrides: [backgroundNetProvider.overrideWith(() => _Fixed(reason))],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/background_net_${reason.name}_$mode.png'),
          );
        });
      }
    }
  });
}
