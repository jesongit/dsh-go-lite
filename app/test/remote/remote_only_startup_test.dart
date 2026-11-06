import 'dart:convert';

import 'package:dsh_app/remote/secret_store.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/ui/remote/remote_screen.dart';
import 'package:dsh_app/ui/shell/root_gate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/golden_harness.dart' show goldenApp, usePhoneSurface;
import 'support/fake_relay.dart';
import 'support/fake_ssh.dart';

class _UnusedSecrets implements SecretStore {
  final calls = <String>[];
  @override
  Future<String?> read(String key) async {
    calls.add('read');
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    calls.add('write');
  }

  @override
  Future<void> delete(String key) async {
    calls.add('delete');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stored in <String?>[
    null,
    '{"kind":"local","id":"local"}',
    '{broken',
    '[]',
    '{"kind":"ssh","id":"gone"}',
  ]) {
    testWidgets('RootGate opens remote setup without network for stored selection $stored', (tester) async {
      SharedPreferences.setMockInitialValues({
        ActiveHostController.prefsKey: ?stored,
        HostsController.prefsKey: jsonEncode([sampleSsh.toJson()]),
      });
      final secrets = _UnusedSecrets();
      final relay = FakeRelayBackend();
      var sshOpens = 0;
      usePhoneSurface(tester);
      final themed = goldenApp(home: const RootGate(), brightness: Brightness.light) as ProviderScope;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secretStoreProvider.overrideWithValue(secrets),
            relayBackendProvider.overrideWithValue(relay),
            networkKicksProvider.overrideWithValue(const Stream.empty()),
            sshLinkFactoryProvider.overrideWithValue((ref, config) {
              sshOpens++;
              throw StateError('startup must not connect an arbitrary host');
            }),
          ],
          child: themed.child,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(RemoteScreen), findsOneWidget);
      final c = ProviderScope.containerOf(tester.element(find.byType(RootGate)));
      expect(c.read(activeHostProvider), HostRef.none);
      expect(c.read(activeConnectionProvider), const AsyncData<HostConnection?>(null));
      expect(sshOpens, 0);
      expect(relay.connected, isEmpty);
      expect(secrets.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final stored in <String?>[null, '{"kind":"local","id":"local"}', '{malformed']) {
    for (final bound in [false, true]) {
      test('no host never reopens a ${bound ? 'bound' : 'legacy unbound'} session: $stored', () async {
        SharedPreferences.setMockInitialValues({
          ActiveHostController.prefsKey: ?stored,
          'last_session_id': 'old-phone-session',
          if (bound) 'last_session_selection': jsonEncode({'host': 'none:', 'sessionId': 'old-phone-session'}),
        });
        final c = ProviderContainer();
        addTearDown(c.dispose);
        c.read(currentSessionProvider);
        await c.read(activeHostProvider.notifier).ready;
        await c.pump();
        expect(c.read(activeHostProvider), HostRef.none);
        expect(c.read(currentSessionProvider), isNull);
        expect((await SharedPreferences.getInstance()).getString('last_session_id'), 'old-phone-session');
      });
    }
  }

  test('loading client settings preserves legacy preferences and never reads or uploads credentials', () async {
    const legacy = <String, Object>{
      'deepseek_api_key': 'legacy-fixture',
      'auto_start_local': true,
      'auto_approve_commands': true,
      'phone_storage': true,
      'custom_provider_ids': <String>['custom-old'],
    };
    SharedPreferences.setMockInitialValues(legacy);
    final secureCalls = <String>[];
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      secureCalls.add(call.method);
      throw StateError('settings must not access legacy secure credentials');
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final secrets = _UnusedSecrets();
    final relay = FakeRelayBackend();
    var network = 0;
    final c = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secrets),
        relayBackendProvider.overrideWithValue(relay),
        sshLinkFactoryProvider.overrideWithValue((ref, config) {
          network++;
          throw StateError('unexpected upload');
        }),
      ],
    );
    addTearDown(c.dispose);
    c.read(settingsProvider);
    await c.read(activeHostProvider.notifier).ready;
    await c.pump();
    expect(c.read(settingsProvider).loaded, isTrue);
    await c.read(settingsProvider.notifier).setHardwareEnterSends(true);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in legacy.entries) {
      expect(prefs.get(entry.key), entry.value);
    }
    expect(secureCalls, isEmpty);
    expect(secrets.calls, isEmpty);
    expect(network, 0);
    expect(relay.connected, isEmpty);
  });
}
