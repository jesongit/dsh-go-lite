import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/session_modes.dart';
import 'package:dsh_app/ui/chat/widgets/plus_panel.dart';
import 'package:dsh_app/ui/features/permission_page.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/support/harness.dart';
import '../plugins/support/fake_plugin_host.dart';

class _SelectedHost extends ActiveHostController {
  @override
  HostRef build() => const HostRef.ssh('pc');
}

void main() {
  for (final surface in ['settings', 'session']) {
    for (final switchHost in [false, true]) {
      testWidgets('remote permission confirmation: $surface / switch=$switchHost', (tester) async {
        SharedPreferences.setMockInitialValues({});
        usePhoneView(tester);
        final first = FakePluginCarrier();
        final second = FakePluginCarrier();
        final clients = [DshClient.withCarrier(first), DshClient.withCarrier(second)];
        for (final client in clients) {
          addTearDown(client.close);
        }
        for (final carrier in [first, second]) {
          carrier.handlers['settings/describe'] = (_) => {
            'writable': true,
            'namespaces': [
              {'ns': 'permission', 'value': <String, Object?>{}, 'revision': 4},
            ],
          };
          carrier.handlers['permissionPresets/catalog'] = (_) => {
            'options': [
              {'value': 'workspace-write', 'name': 'workspace-write'},
              {'value': 'danger-full-access', 'name': 'danger-full-access'},
            ],
            'defaultPreset': 'workspace-write',
          };
          carrier.handlers['session/projections'] = (_) => {
            'kind': 'sequenced',
            'asOfSeq': 1,
            'values': {
              'permissions': {'currentValue': 'danger-full-access'},
            },
          };
          carrier.handlers['settings/mutate'] = (_) => {
            'ns': 'permission',
            'value': {'defaultPreset': 'danger-full-access'},
            'revision': 5,
          };
        }
        await tester.pumpWidget(
          testApp(
            surface == 'settings'
                ? const PermissionPage()
                : const Scaffold(body: SessionPermissionPage(sessionId: 's1')),
            overrides: [
              activeHostProvider.overrideWith(_SelectedHost.new),
              sessionModesProvider.overrideWith((ref, id) => const SessionModes(preset: 'danger-full-access')),
              activeConnectionProvider.overrideWith((ref) {
                final host = ref.watch(activeHostProvider);
                return AsyncData(
                  HostConnection(client: clients[host.id == 'pc' ? 0 : 1], kind: host.kind, hostId: host.id),
                );
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final c = ProviderScope.containerOf(
          tester.element(find.byType(surface == 'settings' ? PermissionPage : SessionPermissionPage)),
        );
        await tester.tap(find.text(surface == 'settings' ? '完全权限' : '设为新对话默认').last);
        await tester.pumpAndSettle();
        expect(find.text('开启完全权限？'), findsOneWidget);
        if (switchHost) {
          c.read(activeHostProvider.notifier).select(const HostRef.relay('other'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(FilledButton, '开启完全权限'));
        await tester.pumpAndSettle();
        expect(first.argsOf('settings/mutate').length, switchHost ? 0 : 1);
        expect(second.argsOf('settings/mutate'), isEmpty);
        expect((await SharedPreferences.getInstance()).containsKey('auto_approve_commands'), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
