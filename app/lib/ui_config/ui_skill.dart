// The dsh-go-ui skill that teaches a host's agent to edit ui.json. The files
// ship in assets/skills/dsh-go-ui/ (flat; manifest.json maps each to its place
// in the skill folder).
//
// Remote hosts: only after the person confirms ([UiSkillRemoteInstaller]):
// over SSH with [uiSkillShellScript], elsewhere by handing the agent
// [uiSkillInstallPrompt] to send.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/hosts_state.dart';

const uiSkillName = 'dsh-go-ui';
const uiSkillAssetDir = 'assets/skills/dsh-go-ui/';

/// The second skill the app ships: teaches a host's agent to write a small
/// local native plugin (sdk/plugin-kit/skill, built into
/// assets/skills/dsh-go-plugin/ by sdk/plugin-kit/scripts/sync-skill.mjs).
/// Available as a bundle in its own folder.
const pluginSkillName = 'dsh-go-plugin';

/// The third: the app's own user guide (docs/guide, built into
/// assets/skills/dsh-go-guide/ by tool/guide_sync.py), so the agent can answer
/// how to use the app. Read-only teaching content.
const guideSkillName = 'dsh-go-guide';

/// The fourth: the bundled troubleshooting and bug-report playbook.
const supportSkillName = 'dsh-go-support';

/// The managed line inside SKILL.md's front matter.
const uiSkillManagedMarker = '# dsh-go:managed';

final _safePath = RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9._-]*(/[A-Za-z0-9_-][A-Za-z0-9._-]*)*$');

/// The skill's files: path inside the skill folder → text.
class UiSkillBundle {
  UiSkillBundle(Map<String, String> files, {this.name = uiSkillName})
    : files = Map.unmodifiable({
        for (final MapEntry(:key, :value) in files.entries)
          if (_safePath.hasMatch(key)) key: value,
      });

  final Map<String, String> files;

  /// The skill's folder name under `$DSH_HOME/skills/`.
  final String name;

  String get skillMd => files['SKILL.md'] ?? '';

  /// SKILL.md last, so DSH never sees the skill before its files.
  List<MapEntry<String, String>> get writeOrder => [
    ...files.entries.where((e) => e.key != 'SKILL.md'),
    ...files.entries.where((e) => e.key == 'SKILL.md'),
  ];
}

typedef UiAssetReader = Future<String> Function(String key);

/// Reads a bundled skill (manifest first): [uiSkillName] unless [name] says
/// otherwise.
Future<UiSkillBundle> loadUiSkillBundle([UiAssetReader? read, String name = uiSkillName]) async {
  final reader = read ?? rootBundle.loadString;
  final assetDir = 'assets/skills/$name/';
  final manifest = jsonDecode(await reader('${assetDir}manifest.json'));
  final files = (manifest as Map)['files'] as Map;
  return UiSkillBundle({
    for (final MapEntry(key: asset, value: target) in files.entries) '$target': await reader('$assetDir$asset'),
  }, name: name);
}

typedef UiSkillBundleLoader = Future<UiSkillBundle> Function();

final uiSkillBundleLoaderProvider = Provider<UiSkillBundleLoader>((ref) => loadUiSkillBundle);

// ── Remote hosts ────────────────────────────────────────────────────────────

/// Installs the skill on a remote host after the person agreed. The app's
/// wiring provides one (SSH: [uiSkillShellScript] over the host's shell;
/// relay: [uiSkillInstallPrompt] into the composer for the person to send);
/// without one, no install entry is shown.
abstract interface class UiSkillRemoteInstaller {
  /// Returns whether the skill was written (or the message handed over).
  Future<bool> install(BuildContext context, HostRef host, UiSkillBundle bundle);
}

final uiSkillRemoteInstallerProvider = Provider<UiSkillRemoteInstaller?>((ref) => null);

/// A POSIX `sh` script that writes [bundle] to
/// `${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-ui/` (leaving a folder the person
/// took over alone) and prints `DSHAPP skill=installed` or
/// `DSHAPP skill=user-owned`.
String uiSkillShellScript(UiSkillBundle bundle) {
  final out = StringBuffer()
    ..writeln('set -e')
    ..writeln('d="\${DSH_HOME:-\$HOME/.dsh}/skills/${bundle.name}"')
    ..writeln(
      'if [ -f "\$d/SKILL.md" ] && ! grep -q \'^ *$uiSkillManagedMarker\' "\$d/SKILL.md"; then '
      "echo 'DSHAPP skill=user-owned'; exit 0; fi",
    );
  final dirs = {
    for (final path in bundle.files.keys)
      if (path.contains('/')) path.substring(0, path.lastIndexOf('/')),
  };
  out.writeln('mkdir -p "\$d"${dirs.map((d) => ' "\$d/$d"').join()}');
  var n = 0;
  for (final MapEntry(key: path, value: text) in bundle.writeOrder) {
    var tag = 'DSHGO_EOF_$n';
    while (text.split('\n').contains(tag)) {
      tag = '${tag}_';
    }
    n++;
    final body = text.endsWith('\n') ? text : '$text\n';
    out
      ..writeln("cat > \"\$d/$path.dsh-go-tmp\" <<'$tag'")
      ..write(body)
      ..writeln(tag)
      ..writeln('mv "\$d/$path.dsh-go-tmp" "\$d/$path"');
  }
  out.writeln("echo 'DSHAPP skill=installed'");
  return out.toString();
}

/// A message for the remote agent: the skill's working files and where to
/// put them. The person sends it themself.
String uiSkillInstallPrompt(UiSkillBundle bundle) {
  final out = StringBuffer()
    ..writeln(appL10n.shellSkillInstallPrompt(uiSkillName))
    ..writeln()
    ..writeln(appL10n.shellSkillInstallDirectory(uiSkillName))
    ..writeln(appL10n.shellSkillInstallFiles)
    ..writeln(
      appL10n.shellSkillInstallCheck('`node "\${DSH_HOME:-\$HOME/.dsh}/skills/$uiSkillName/scripts/check.mjs"`'),
    )
    ..writeln(appL10n.shellSkillInstallConfirm);
  for (final path in const ['SKILL.md', 'schema.json', 'scripts/check.mjs']) {
    final text = bundle.files[path];
    if (text == null) continue;
    final lang = switch (path.split('.').last) {
      'md' => 'markdown',
      'json' => 'json',
      _ => 'js',
    };
    out
      ..writeln()
      ..writeln(appL10n.shellSkillInstallFile(path))
      ..writeln()
      ..writeln('````$lang')
      ..write(text.endsWith('\n') ? text : '$text\n')
      ..writeln('````');
  }
  return out.toString();
}
