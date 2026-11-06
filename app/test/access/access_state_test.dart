import 'package:dsh_app/state/access_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('remote client permissions cover files, pets, background and voice only', () {
    expect(AccessFeature.values.map((v) => v.name), ['files', 'pet', 'background', 'voice']);
    expect(accessItemsFor(AccessFeature.files, null), [AccessItem.storage]);
    expect(accessItemsFor(AccessFeature.pet, null), [AccessItem.overlay]);
    expect(accessItemsFor(AccessFeature.voice, null), [AccessItem.mic]);
    expect(accessItemsFor(AccessFeature.background, 'vivo'), [
      AccessItem.notifications,
      AccessItem.battery,
      AccessItem.vendorBackground,
      AccessItem.autostart,
    ]);
    expect(accessItemsFor(AccessFeature.background, null), [AccessItem.notifications, AccessItem.battery]);
    expect(accessWalk(AccessFeature.values, 'vivo'), AccessItem.values);
  });

  test('unknown native readings stay unknown and vendor visits are explicit', () {
    expect(accessStateOf(AccessItem.storage, const AccessReadings(), {}), isNull);
    expect(accessStateOf(AccessItem.storage, const AccessReadings(storage: false), {}), AccessState.off);
    expect(accessStateOf(AccessItem.overlay, const AccessReadings(overlay: true), {}), AccessState.on);
    expect(accessStateOf(AccessItem.autostart, const AccessReadings(), {}), AccessState.unknown);
    expect(accessStateOf(AccessItem.autostart, const AccessReadings(), {AccessItem.autostart}), AccessState.visited);
  });

  test('vendor visits persist and removed phone items are ignored on migration', () async {
    SharedPreferences.setMockInitialValues({
      AccessVisitedController.prefsKey: ['popup', 'accessibility'],
    });
    final first = ProviderContainer();
    first.read(accessVisitedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(first.read(accessVisitedProvider), isEmpty);
    await first.read(accessVisitedProvider.notifier).mark(AccessItem.autostart);
    first.dispose();
    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(accessVisitedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(next.read(accessVisitedProvider), {AccessItem.autostart});
  });
}
