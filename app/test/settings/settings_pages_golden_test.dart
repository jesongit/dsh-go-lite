import 'package:dsh_app/platform/platform_state.dart';
import 'package:dsh_app/ui/settings/background_guide_page.dart';
import 'package:dsh_app/ui/settings/diagnostics_page.dart';

import '../shell/golden_harness.dart';

void main() {
  goldenBoth('diagnostics_remote_client', () => const DiagnosticsPage());
  goldenBoth(
    'background_guide',
    () => const BackgroundGuidePage(),
    overrides: () => [batteryExemptProvider.overrideWith((ref) async => false)],
  );
}
