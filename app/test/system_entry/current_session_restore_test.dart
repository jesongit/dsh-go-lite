// A cold start from a share or 新对话 picks the new chat before the last
// open conversation has been read back; that late read must not switch away.

import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an early choice of 新对话 survives the restore of the last conversation', () async {
    SharedPreferences.setMockInitialValues({'last_session_id': 'old'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentSessionProvider), isNull);
    container.read(currentSessionProvider.notifier).select(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(currentSessionProvider), isNull);
  });

  test('a legacy unbound conversation stays closed without a host', () async {
    SharedPreferences.setMockInitialValues({'last_session_id': 'old'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentSessionProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(activeHostProvider), HostRef.none);
    expect(container.read(currentSessionProvider), isNull);
  });
}
