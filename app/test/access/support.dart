// A phone for the system-permission pages: readings set by the test, and
// trips to system settings that come back with whatever the test says the
// person did there. And the local engine as the native side keeps it, for
// what first run's end turns on.


import 'package:dsh_app/state/access_state.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Every item off, on a phone that reports them all.
const offPhone = AccessReadings(
  vendor: 'vivo',
  appLabel: 'DSH Go',
  mic: false,
  storage: false,
  notifications: false,
  battery: false,
  overlay: false,
  sdk: 34,
  metered: false,
);

AccessReadings readingsWith(
  AccessReadings r, {
  String? vendor,
  bool clearVendor = false,
  bool? mic,
  bool? storage,
  bool? notifications,
  bool? battery,
  bool? overlay,
  bool? metered,
}) => AccessReadings(
  vendor: clearVendor ? null : (vendor ?? r.vendor),
  appLabel: r.appLabel,
  mic: mic ?? r.mic,
  storage: storage ?? r.storage,
  notifications: notifications ?? r.notifications,
  battery: battery ?? r.battery,
  overlay: overlay ?? r.overlay,
  overlayBlocked: r.overlayBlocked,
  sdk: r.sdk,
  metered: metered ?? r.metered,
);

/// What the person does in system settings for an item: the readings after.
typedef Answer = AccessReadings Function(AccessItem item, AccessReadings now);

class FakeAccessDriver implements AccessDriver {
  FakeAccessDriver(this.readings, {this.answer});

  AccessReadings readings;
  Answer? answer;

  /// `mic`, `notifications+` (again), `appInfo`, in order.
  final opened = <String>[];
  int reads = 0;

  @override
  Future<AccessReadings> read() async {
    reads++;
    return readings;
  }

  @override
  Future<bool> open(AccessItem item, {bool again = false}) async {
    opened.add(again ? '${item.name}+' : item.name);
    if (answer case final answer?) readings = answer(item, readings);
    return true;
  }

  @override
  Future<bool> openAppInfo() async {
    opened.add('appInfo');
    if (answer case final answer?) readings = answer(AccessItem.overlay, readings);
    return true;
  }
}

/// Readings that fail [failures] more times from when the test says so (the
/// phone did not answer).
class FlakyAccessDriver extends FakeAccessDriver {
  FlakyAccessDriver(super.readings, {super.answer});

  int failures = 0;

  @override
  Future<AccessReadings> read() async {
    if (failures > 0) {
      failures--;
      reads++;
      throw PlatformException(code: 'unavailable', message: 'the phone did not answer');
    }
    return super.read();
  }
}

List<Override> accessOverrides(FakeAccessDriver driver) => [accessDriverProvider.overrideWithValue(driver)];

/// The person leaves for system settings and comes back.
Future<void> awayAndBack(WidgetTester tester) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
