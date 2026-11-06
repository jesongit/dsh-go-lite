// Bundled UI skill, the remote SSH installer and agent installation prompt.

import 'dart:io';

import 'package:dsh_app/ui_config/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late UiSkillBundle bundle;

  setUpAll(() async => bundle = await loadUiSkillBundle(readAssetFromDisk));

  void expectInstalled(Directory dir) {
    for (final MapEntry(key: path, value: text) in bundle.files.entries) {
      expect(File('${dir.path}/$path').readAsStringSync(), text, reason: path);
    }
    expect(dir.listSync(recursive: true).where((e) => e.path.endsWith('.dsh-go-tmp')), isEmpty);
  }

  test('the bundle has the skill, the schema, the checker and examples in place', () {
    expect(bundle.files.keys, containsAll(['SKILL.md', 'schema.json', 'scripts/check.mjs', 'examples/full.json']));
    expect(bundle.writeOrder.last.key, 'SKILL.md');
  });

  group('remote', () {
    late Directory home;
    setUp(() => home = Directory.systemTemp.createTempSync('ui-skill-home-'));
    tearDown(() => home.deleteSync(recursive: true));

    Future<ProcessResult> sh(String script, Map<String, String> env) =>
        Process.run('/bin/sh', ['-c', script], environment: env, includeParentEnvironment: false);

    test('the SSH script writes the skill under \$DSH_HOME, byte for byte', () async {
      final r = await sh(uiSkillShellScript(bundle), {'DSH_HOME': '${home.path}/dsh', 'PATH': '/usr/bin:/bin'});
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(r.stdout, contains('DSHAPP skill=installed'));
      expectInstalled(Directory('${home.path}/dsh/skills/dsh-go-ui'));
    }, skip: Platform.isWindows ? 'Requires POSIX /bin/sh' : false);

    test('without DSH_HOME it uses ~/.dsh, and leaves a folder the person took over', () async {
      final env = {'HOME': home.path, 'PATH': '/usr/bin:/bin'};
      expect((await sh(uiSkillShellScript(bundle), env)).exitCode, 0);
      final dir = Directory('${home.path}/.dsh/skills/dsh-go-ui');
      expectInstalled(dir);
      final skill = File('${dir.path}/SKILL.md');
      skill.writeAsStringSync(
        skill.readAsStringSync().replaceFirst(RegExp(r'^# dsh-go:managed.*\n', multiLine: true), ''),
      );
      File('${dir.path}/schema.json').writeAsStringSync('{}');
      final r = await sh(uiSkillShellScript(bundle), env);
      expect(r.stdout, contains('DSHAPP skill=user-owned'));
      expect(File('${dir.path}/schema.json').readAsStringSync(), '{}');
    }, skip: Platform.isWindows ? 'Requires POSIX /bin/sh' : false);

    test('the message for other hosts carries the working files', () {
      final prompt = uiSkillInstallPrompt(bundle);
      expect(prompt, contains(r'$DSH_HOME/skills/dsh-go-ui/'));
      for (final path in ['SKILL.md', 'schema.json', 'scripts/check.mjs']) {
        expect(prompt, contains('文件 `$path`：'));
        expect(prompt, contains(bundle.files[path]!.trimRight()));
      }
      expect(prompt, isNot(contains('examples/full.json')));
    });
  });
}
