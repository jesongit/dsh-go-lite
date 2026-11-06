import 'dart:async';

import 'package:dsh_app/pets/pet_signals.dart';
import 'package:dsh_app/pets/pet_overlay_actions.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notify/support.dart' show session, settle;
import '../support/remote_hosts.dart';

class _Mux extends DshMux {
  _Mux(super.carrier);

  @override
  MuxGeneration get generation => const MuxGeneration(1, 'pet-client', '/tmp');
}

class _Client extends DshClient {
  _Client(this.sessions) : super(DshConnection(Uri.parse('http://127.0.0.1:9')));

  final List<SessionSummary> sessions;
  final events = StreamController<HostEvent>.broadcast(sync: true);
  late final _generation = _Mux(carrier);

  @override
  DshMux get mux => _generation;

  @override
  Stream<HostEvent> get hostEvents => events.stream;

  @override
  Future<List<SessionSummary>> listSessions() async => sessions;
}

class _RelayAccount extends RelayAccountController {
  @override
  Future<RelayAccountState> build() async => const RelayAccountState();
}

void main() {
  const first = HostRef.ssh('first');
  const second = HostRef.relay('second');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only the selected remote host contributes runs after switching', () async {
    final a = _Client([session('a', running: true)]);
    final b = _Client([session('b', running: true)]);
    final hostOverride = activeHostProvider.overrideWith(() => FixedActiveHost(first));
    final c = ProviderContainer(
      overrides: [
        hostOverride,
        activeConnectionProvider.overrideWithValue(
          AsyncData(HostConnection(client: a, kind: HostKind.ssh, hostId: first.id)),
        ),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await a.events.close();
      await b.events.close();
      await a.close();
      await b.close();
    });
    c.listen(petRunsProvider, (_, _) {});
    await settle();
    expect(c.read(petRunsProvider).map((r) => (r.host, r.sessionId)), [(first, 'a')]);

    c.read(activeHostProvider.notifier).select(second);
    c.updateOverrides([
      hostOverride,
      activeConnectionProvider.overrideWithValue(
        AsyncData(HostConnection(client: b, kind: HostKind.relay, hostId: second.id)),
      ),
    ]);
    await settle();
    a.events.add(const SessionStatusEvent('old-host-late-event', true));
    await settle();
    expect(c.read(petRunsProvider).map((r) => (r.host, r.sessionId)), [(second, 'b')]);

    c.read(activeHostProvider.notifier).select(HostRef.none);
    c.updateOverrides([hostOverride, activeConnectionProvider.overrideWithValue(const AsyncData(null))]);
    await settle();
    b.events.add(const SessionStatusEvent('disconnected-host-late-event', true));
    await settle();
    expect(c.read(petRunsProvider), isEmpty);
  });

  test('no selection has no runs or built-in local host choice', () {
    final c = ProviderContainer(
      overrides: [
        activeHostProvider.overrideWith(() => FixedActiveHost(HostRef.none)),
        hostsProvider.overrideWith(FixedHosts.new),
        relayAccountProvider.overrideWith(_RelayAccount.new),
        activeConnectionProvider.overrideWithValue(const AsyncData(null)),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(petRunsProvider), isEmpty);
    expect(c.read(petHostChoicesProvider), isEmpty);
  });
}
