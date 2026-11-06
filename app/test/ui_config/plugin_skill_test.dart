// The plugin SDK skill remains bundled and can generate a remote SSH installer.

import 'package:dsh_app/ui_config/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late UiSkillBundle ui;
  late UiSkillBundle plugin;

  setUpAll(() async {
    ui = await loadUiSkillBundle(readAssetFromDisk);
    plugin = await loadUiSkillBundle(readAssetFromDisk, pluginSkillName);
  });

  test('the plugin skill bundle: checker, schemas, template; SKILL.md last and managed', () {
    expect(plugin.name, pluginSkillName);
    expect(ui.name, uiSkillName);
    expect(
      plugin.files.keys,
      containsAll([
        'SKILL.md',
        'kit/bin/check.mjs',
        'kit/lib/check.js',
        'kit/lib/bridge/manifest.js',
        'kit/schema/view.schema.json',
        'template/package.json',
        'template/cordis.patch.yml',
        'template/lib/index.js',
      ]),
    );
    expect(plugin.writeOrder.last.key, 'SKILL.md');
    expect(plugin.skillMd, contains(uiSkillManagedMarker));
  });

  test('the SSH script writes the plugin skill into its own folder', () {
    final script = uiSkillShellScript(plugin);
    expect(script, contains('/skills/dsh-go-plugin"'));
    expect(script, contains('"\$d/kit/lib/bridge"'));
  });
}
