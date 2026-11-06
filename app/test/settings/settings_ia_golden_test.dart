import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/ui/settings/about_page.dart';
import 'package:dsh_app/ui/settings/interface_page.dart';
import 'package:dsh_app/ui/settings/personalization_page.dart';
import 'package:dsh_app/ui/settings/privacy_page.dart';
import 'package:dsh_app/ui/settings/settings_screen.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine_settings/support.dart' as engine;
import '../support/remote_hosts.dart';
import '../shell/golden_harness.dart';

List<Override> _remote() => [
  activeHostProvider.overrideWith(() => FixedActiveHost(const HostRef.ssh('lab'))),
  hostsProvider.overrideWith(FixedHosts.new),
  hostLinkStatusProvider.overrideWith((ref, host) => const Stream.empty()),
  networkKicksProvider.overrideWithValue(const Stream.empty()),
  settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true))),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  goldenBoth('settings_remote_hub', () => const SettingsScreen(), overrides: _remote);
  goldenBoth('personalization_remote_client', () => const PersonalizationPage(), overrides: _remote);
  goldenBoth('about', () => const AboutPage(), overrides: _remote);

  for (final (name, page) in [('interface', const InterfacePage()), ('privacy', const PrivacyPage())]) {
    for (final brightness in Brightness.values) {
      testWidgets('$name (${brightness.name})', (tester) async {
        await engine.pumpPage(
          tester,
          page,
          overrides: engine.engineOverrides(DshClient.withCarrier(engine.FakeSettingsHost())),
          brightness: brightness,
          height: name == 'interface' ? 1500 : 844,
          fonts: true,
        );
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${brightness.name}.png'));
      });
    }
  }
}
