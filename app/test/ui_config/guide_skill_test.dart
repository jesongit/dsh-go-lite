// The guide generated from docs/guide remains available as bundled teaching assets.

import 'dart:convert';
import 'dart:io';

import 'package:dsh_app/ui_config/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UiSkillBundle guide;

  setUpAll(() async => guide = await loadUiSkillBundle(readAssetFromDisk, guideSkillName));
  test('the bundle: every asset mapped, both languages page for page, links resolve, SKILL.md managed and last', () {
    final assets = Directory('$appDir/assets/skills/$guideSkillName');
    final manifest = jsonDecode(File('${assets.path}/manifest.json').readAsStringSync()) as Map;
    expect(manifest['name'], guideSkillName);
    final files = (manifest['files'] as Map).cast<String, String>();
    expect(files.keys.toSet(), {for (final f in assets.listSync()) f.uri.pathSegments.last}..remove('manifest.json'));

    expect(guide.name, guideSkillName);
    expect(guide.files.keys.toSet(), files.values.toSet());
    expect(guide.files.keys, containsAll(['SKILL.md', 'README.md']));
    expect(guide.writeOrder.last.key, 'SKILL.md');
    expect(guide.skillMd.split('\n').first.trimRight(), '---');
    expect(guide.skillMd, contains(uiSkillManagedMarker));
    expect(guide.skillMd.replaceAll('\r\n', '\n'), contains('name: $guideSkillName\n'));

    Set<String> pages(String locale) => {
      for (final path in guide.files.keys)
        if (path.startsWith('$locale/')) path.substring(locale.length + 1),
    };
    expect(pages('zh'), isNotEmpty);
    expect(pages('en'), pages('zh'));

    // Relative links land on a file of the bundle, wherever it is installed.
    final link = RegExp(r'\]\(([^)\s]+)\)');
    for (final MapEntry(key: path, value: text) in guide.files.entries) {
      for (final match in link.allMatches(text)) {
        final target = match[1]!;
        if (RegExp(r'^(https?|mailto|dshgo):').hasMatch(target)) continue;
        final resolved = Uri.parse(path).resolve(target.split('#').first).path;
        expect(guide.files.keys, contains(resolved), reason: '$path → $target');
      }
    }
  });
}
