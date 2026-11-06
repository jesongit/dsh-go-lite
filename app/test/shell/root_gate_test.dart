import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/state/ui_mode_state.dart';
import 'package:dsh_app/ui/remote/remote_screen.dart';
import 'package:dsh_app/ui/shell/root_gate.dart';
import 'package:dsh_app/ui/web/mode_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

class _Host extends ActiveHostController {
  _Host(this.initial);
  final HostRef initial;

  @override
  HostRef build() => initial;

  @override
  Future<void> get ready async {}

  void use(HostRef host) => state = host;
}

class _Settings extends FakeSettings {
  _Settings() : super(const AppSettings());

  void loaded() => state = const AppSettings(loaded: true);
}

// Hold the nested home at its own preference boundary so these assertions
// exercise the root route without starting chat or a WebView.
class _PendingMode extends UiModeController {
  @override
  UiModeState build() => const UiModeState();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('waits for client preferences, then an explicit no-host choice opens remote connections', (tester) async {
    final settings = _Settings();
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(
        home: const RootGate(),
        brightness: Brightness.light,
        overrides: [
          settingsProvider.overrideWith(() => settings),
          activeHostProvider.overrideWith(() => _Host(HostRef.none)),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(RemoteScreen), findsNothing);
    expect(find.byType(ModeHome), findsNothing);
    settings.loaded();
    await tester.pump();
    await tester.pump();
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.byType(ModeHome), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected remote host opens mode home and clearing selection returns to connections', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      goldenApp(
        home: const RootGate(),
        brightness: Brightness.light,
        overrides: [
          settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true))),
          activeHostProvider.overrideWith(() => _Host(const HostRef.ssh('lab'))),
          uiModeProvider.overrideWith(_PendingMode.new),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ModeHome), findsOneWidget);
    expect(find.byType(RemoteScreen), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(RootGate)));
    (container.read(activeHostProvider.notifier) as _Host).use(HostRef.none);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.byType(ModeHome), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
