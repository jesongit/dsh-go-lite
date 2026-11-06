// The host label under the chat title follows the app language, also on a
// connection made before the language changed.

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/ui/chat/widgets/whale_tail.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/english_preview.dart';

DshClient _client() {
  final c = DshClient(DshConnection(Uri.parse('http://127.0.0.1:9')));
  addTearDown(c.close);
  return c;
}

/// Chinese for this test, whatever the run defaults to.
void _useChinese() {
  AppLocale.use(AppLocale.zhCN);
  addTearDown(() => AppLocale.use(englishPreview ? AppLocale.en : AppLocale.zhCN));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(WhaleSprites.load);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remote labels keep the host name and translate the rest', () {
    _useChinese();
    final ssh = HostConnection(client: _client(), kind: HostKind.ssh, hostId: 'mac', name: '书房的 Mac');
    final relay = HostConnection(client: _client(), kind: HostKind.relay, hostId: 'r1');
    expect(ssh.label, '书房的 Mac · SSH');
    expect(relay.label, '远程主机 · 远程');

    useEnglish();
    expect(ssh.label, '书房的 Mac · SSH');
    expect(relay.label, 'Remote host · Remote');
  });

  test('a fixed label wins', () {
    useEnglish();
    expect(HostConnection(client: _client(), hostId: 'test-host', label: '电脑').label, '电脑');
  });
}
