import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/ui/remote/remote_screen.dart';
import 'package:dsh_app/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/remote_hosts.dart';
import '../shell/golden_harness.dart';

void main() {
  testWidgets('no-host connection screen keeps client settings accessible', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(goldenApp(home: const RemoteScreen(), brightness: Brightness.light, overrides: [activeHostProvider.overrideWith(() => FixedActiveHost(HostRef.none))]));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  for (final phase in [HostLinkPhase.connected, HostLinkPhase.failed]) {
    testWidgets('remote overview reports ${phase.name}', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        goldenApp(
          home: const Scaffold(body: SettingsOverview()),
          brightness: Brightness.light,
          overrides: [
            activeHostProvider.overrideWith(() => FixedActiveHost(const HostRef.ssh('lab'))),
            hostsProvider.overrideWith(FixedHosts.new),
            hostLinkStatusProvider.overrideWith((ref, host) => Stream.value(HostLinkStatus(phase))),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('实验室服务器'), findsOneWidget);
      expect(find.text(phase == HostLinkPhase.connected ? '已连接' : '连接失败'), findsOneWidget);
      expect(find.textContaining('本机引擎'), findsNothing);
    });
  }

  testWidgets('no selection opens remote connection settings without local sign-in', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(
        home: const Scaffold(body: SettingsOverview()),
        brightness: Brightness.light,
        overrides: [activeHostProvider.overrideWith(() => FixedActiveHost(HostRef.none))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('登录 DeepSeek 账号'), findsNothing);
    await tester.tap(find.byType(SettingsOverview));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteScreen), findsOneWidget);
  });
}
