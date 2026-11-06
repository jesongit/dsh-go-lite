import 'package:dsh_app/ui/settings/system_access_page.dart';

import '../shell/golden_harness.dart';
import 'support.dart';

void main() {
  goldenBoth(
    'system_access_remote_client',
    () => const SystemAccessPage(),
    overrides: () => accessOverrides(FakeAccessDriver(offPhone)),
  );
}
