import 'package:dsh_app/state/access_state.dart';
import 'package:dsh_app/ui/access/access_walk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/golden_harness.dart';
import 'support.dart';

void main() {
  for (final item in [AccessItem.mic, AccessItem.storage, AccessItem.battery, AccessItem.overlay]) {
    testWidgets('${item.name} permission remains usable with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        goldenApp(
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2,
            maxScaleFactor: 2,
            child: AccessWalk(items: [item], onDone: () {}),
          ),
          brightness: Brightness.light,
          overrides: accessOverrides(FakeAccessDriver(offPhone)),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('access-primary'));
      await tester.ensureVisible(button);
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
