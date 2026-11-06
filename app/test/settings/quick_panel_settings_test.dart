import 'package:dsh_app/state/quick_panel_state.dart';
import 'package:dsh_app/ui/settings/interface_page.dart';
import 'package:dsh_app/ui/settings/quick_panel_items_sheet.dart';
import 'package:dsh_app/ui/shell/sessions_drawer.dart' show DrawerDestination;
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine_settings/support.dart' as engine;

Future<void> _pump(WidgetTester tester) => engine.pumpPage(
  tester,
  const InterfacePage(),
  overrides: engine.engineOverrides(DshClient.withCarrier(engine.FakeSettingsHost())),
  height: 1600,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('default client shortcuts are plugins, remote hosts and settings', (tester) async {
    await _pump(tester);
    expect(find.text('插件、远程主机、设置'), findsOneWidget);
    expect(find.textContaining('本机引擎'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quick-panel-items')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickPanelItemsSheet), findsOneWidget);
    expect(find.byKey(const ValueKey(DrawerDestination.remote)), findsOneWidget);
  });

  testWidgets('swipe switch persists a deliberate client preference', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('quick-panel-swipe')));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(InterfacePage)));
    expect(c.read(quickPanelProvider).swipe, isFalse);
    expect((await SharedPreferences.getInstance()).getBool(QuickPanelController.swipeKey), isFalse);
  });

  test('stored local engine shortcuts disappear while remote order is kept', () async {
    SharedPreferences.setMockInitialValues({
      QuickPanelController.itemsKey: ['features', 'engine', 'remote', 'features', 'settings'],
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(quickPanelProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(quickPanelProvider).items, [
      DrawerDestination.features,
      DrawerDestination.remote,
      DrawerDestination.settings,
    ]);
    await c.read(quickPanelProvider.notifier).setItems([DrawerDestination.remote, DrawerDestination.plugins]);
    expect((await SharedPreferences.getInstance()).getStringList(QuickPanelController.itemsKey), ['remote', 'plugins']);
  });
}
