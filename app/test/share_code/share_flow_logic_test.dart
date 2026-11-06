import 'package:dsh_app/share_code/profile_export.dart';
import 'package:dsh_app/share_code/share_codec.dart';
import 'package:dsh_app/share_code/share_code_state.dart';
import 'package:dsh_app/share_code/share_import.dart';
import 'package:dsh_app/share_code/share_link.dart';
import 'package:dsh_app/share_code/share_models.dart';
import 'package:dsh_app/share_code/share_net.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_engine.dart';

const _integrity = 'sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==';

HostConnection _host(DshClient client, {String label = 'Mac · SSH'}) =>
    HostConnection(client: client, label: label, kind: HostKind.ssh, hostId: 'mac');

FakeEngine _sourceEngine() {
  final e = FakeEngine()
    ..addSettings('subagent', base: {'maxDepth': 1}, user: {'maxDepth': 3})
    ..addSettings(
      'web-search-deepseek',
      base: {'model': 'flash'},
      user: {'apiKeyEnv': 'MY_KEY', 'apiKey': 'sk-abcdefabcdef1234567890'},
    )
    ..addSettings('ui-settings-account', user: {'step': 3})
    ..addSettings('ui-theme', base: {'preference': 'system'})
    ..addBundle(
      'dsh-notes',
      version: '1.4.2',
      source: 'dsh-notes@^1.4.0',
      title: '读书笔记',
      rows: [
        {'rowId': 'preset-writer', 'moduleName': agentPresetModule},
        {'rowId': 'notes', 'moduleName': 'dsh-notes'},
      ],
    )
    ..addBundle('dsh-writer', version: '2.0.0', source: 'github:acme/dsh-writer#v2.0.0')
    ..addBundle('my-local', version: '0.0.1', source: '/root/plugins/my-local')
    ..addBundle(
      '@deepseek-ai/dsh-experimental-session-titles-bundle',
      official: true,
      optional: true,
      enabled: true,
      installed: false,
    )
    ..addBundle(
      '@deepseek-ai/dsh-experimental-terminal-bundle',
      official: true,
      optional: true,
      enabled: false,
      installed: false,
    )
    ..addBundle('@deepseek-ai/dsh-base', installed: false);
  e.presets.add({'id': 'writer', 'name': '写作'});
  return e;
}

void main() {
  group('export', () {
    test('lists what can travel, with sizes, and builds the share from the ticks', () async {
      final client = DshClient.withCarrier(_sourceEngine());
      final source = await loadProfileExport(client, hostLabel: 'Mac · SSH');

      expect(source.section(ExportSection.settings).map((i) => i.id), [
        'settings:subagent',
        'settings:web-search-deepseek',
      ]);
      expect(source.settings['web-search-deepseek'], {'apiKeyEnv': 'MY_KEY'});
      final plugins = {for (final i in source.section(ExportSection.plugins)) i.id: i};
      expect(plugins.keys, [
        'plugin:dsh-notes',
        'plugin:dsh-writer',
        'plugin:my-local',
        'plugin:@deepseek-ai/dsh-experimental-session-titles-bundle',
      ]);
      expect(plugins['plugin:dsh-notes']!.subtitle, 'npm · 1.4.2 · 含预设「写作」');
      expect(plugins['plugin:dsh-writer']!.subtitle, 'GitHub · acme/dsh-writer');
      expect(plugins['plugin:my-local']!.available, isFalse);
      expect(source.section(ExportSection.skills), isEmpty);
      expect(source.section(ExportSection.agentsMd), isEmpty);
      expect(source.items.every((i) => !i.available || i.bytes > 0), isTrue);

      final selected = source.defaultSelection;
      expect(selected.contains('agents-md'), isFalse);
      expect(selected.contains('plugin:my-local'), isFalse);
      final share = source.build({...selected, 'agents-md'}, now: DateTime.utc(2026, 10, 24));
      expect(share.plugins.map((p) => p.spec), ['dsh-notes@1.4.2', 'github:acme/dsh-writer#v2.0.0', null]);
      expect(share.presets.single.id, 'writer');
      expect(share.skills, isEmpty);
      expect(share.agentsMd, isNull);

      final back = decodeShareCode(encodeShareCode(share)) as ProfileShare;
      expect(back.toJson(), share.toJson());

      // Without a plugin, its preset doesn't travel either.
      expect(source.build(selected.difference({'plugin:dsh-notes'})).presets, isEmpty);
    });

    test('a remote engine offers no files', () async {
      final client = DshClient.withCarrier(_sourceEngine());
      final source = await loadProfileExport(client, hostLabel: 'Mac · SSH');
      expect(source.section(ExportSection.skills), isEmpty);
      expect(source.section(ExportSection.agentsMd), isEmpty);
    });

    test('npm integrity is added when the registry answers', () async {
      final net = FakeShareNet()..npm['dsh-notes@1.4.2'] = const NpmFacts(integrity: _integrity, publisher: 'acme');
      final share = await withProfileNpmFacts(
        net,
        const ProfileShare(
          plugins: [
            SharedPlugin(name: 'dsh-notes', source: PluginSourceKind.npm, spec: 'dsh-notes@1.4.2', version: '1.4.2'),
          ],
        ),
      );
      expect(share.plugins.single.integrity, _integrity);
      expect(share.plugins.single.author, 'acme');
    });
  });

  group('import', () {
    late FakeEngine engine;
    late DshClient client;
    late FakeShareNet net;

    ProfileShare profile({String integrity = _integrity}) => ProfileShare(
      settings: const {
        'subagent': {'maxDepth': 3},
        'ui-theme': {'preference': 'system'},
        'cot-translation': {'target': 'zh'},
      },
      plugins: [
        SharedPlugin(
          name: 'dsh-notes',
          source: PluginSourceKind.npm,
          spec: 'dsh-notes@1.4.2',
          version: '1.4.2',
          integrity: integrity,
          title: '读书笔记',
        ),
        const SharedPlugin(name: 'dsh-writer', source: PluginSourceKind.github, spec: 'github:acme/dsh-writer#v2.0.0'),
        const SharedPlugin(
          name: '@deepseek-ai/dsh-experimental-session-titles-bundle',
          source: PluginSourceKind.official,
          title: '对话标题',
        ),
      ],
      presets: const [
        SharedPreset(id: 'writer', name: '写作', bundle: 'dsh-notes'),
        SharedPreset(id: 'standard', bundle: 'dsh-notes'),
      ],
      skills: const [
        SharedSkill(name: 'outline', files: {'SKILL.md': '新的提纲技能'}),
        SharedSkill(name: 'quick', files: {'SKILL.md': '简短'}),
      ],
      agentsMd: '回答用中文。',
    );

    setUp(() {
      engine = FakeEngine()
        ..addSettings('subagent', base: {'maxDepth': 1})
        ..addSettings('ui-theme', base: {'preference': 'system'})
        ..addBundle('dsh-notes', version: '1.2.0', source: 'dsh-notes@1.2.0')
        ..addBundle(
          '@deepseek-ai/dsh-experimental-session-titles-bundle',
          official: true,
          optional: true,
          enabled: false,
          installed: false,
        );
      engine.presets.add({'id': 'standard'});
      client = DshClient.withCarrier(engine);
      net = FakeShareNet()
        ..npm['dsh-notes@1.4.2'] = const NpmFacts(integrity: _integrity, publisher: 'acme', unpackedSize: 9615);
    });

    test('the diff: upgrades, installs, switches, presets, settings, files', () async {
      final plan = await planImport(profile(), ImportTarget(_host(client), isActive: true), net: net);
      final byId = {for (final c in plan.changes) c.id: c};

      final notes = byId['plugin:dsh-notes']!;
      expect(notes.kind, ChangeKind.upgrade);
      expect(notes.detail, '1.2.0 → 1.4.2');
      expect(notes.integrity, IntegrityStatus.verified);
      expect(notes.facts?.publisher, 'acme');
      expect(byId['plugin:dsh-writer']!.kind, ChangeKind.install);
      expect(byId['plugin:dsh-writer']!.integrity, IntegrityStatus.unverifiable);
      expect(byId['plugin:@deepseek-ai/dsh-experimental-session-titles-bundle']!.kind, ChangeKind.enable);

      expect(byId['preset:writer']!.follows, 'plugin:dsh-notes');
      expect(byId.containsKey('preset:standard'), isFalse, reason: 'already there');

      expect(byId['settings:subagent']!.detail, 'maxDepth 1 → 3');
      expect(byId['settings:subagent']!.kind, ChangeKind.change);
      expect(byId.containsKey('settings:ui-theme'), isFalse, reason: 'already the same');
      expect(byId['settings:cot-translation']!.detail, startsWith('装好插件后应用'));

      expect(byId['skill:outline']!.kind, ChangeKind.unavailable);
      expect(byId['skill:outline']!.toggleable, isFalse);
      expect(byId['skill:quick']!.kind, ChangeKind.unavailable);
      expect(byId['skill:quick']!.toggleable, isFalse);
      expect(plan.defaultSelection, isNot(contains('agents-md')));
      expect(byId['agents-md']!.kind, ChangeKind.unavailable);

      expect(plan.defaultSelection, isNot(contains('skill:outline')));
      expect(plan.defaultSelection, isNot(contains('preset:writer')), reason: 'presets follow their plugin');
    });

    test('a changed package or a host that cannot install blocks the plugin rows', () async {
      final mismatch = await planImport(
        profile(integrity: 'sha512-AAAA'),
        ImportTarget(_host(client), isActive: true),
        net: net,
      );
      expect(mismatch.changes.firstWhere((c) => c.id == 'plugin:dsh-notes').blocked, '与分享时的版本不一致');
      expect(mismatch.changes.firstWhere((c) => c.id == 'plugin:dsh-notes').integrity, IntegrityStatus.mismatch);

      final relay = DshClient.withCarrier(FakeEngine(allowInstall: false)..addSettings('subagent'));
      final plan = await planImport(profile(), ImportTarget(_host(relay, label: 'Mac · 远程'), isActive: true), net: net);
      expect(plan.changes.firstWhere((c) => c.id == 'plugin:dsh-writer').blocked, '这台主机不能从这里安装插件');
      expect(plan.changes.firstWhere((c) => c.id == 'skill:quick').blocked, '这台主机不支持这个操作');
      expect(plan.changes.firstWhere((c) => c.id == 'agents-md').toggleable, isFalse);
    });

    test('applies remote plugins and settings in order, leaving unsupported files unapplied', () async {
      final plan = await planImport(profile(), ImportTarget(_host(client), isActive: false), net: net);
      final steps = <String>[];
      final result = await applyImport(
        plan,
        {...plan.defaultSelection, 'skill:outline', 'skill:quick', 'agents-md'},
        runner: DirectPluginRunner(client),
        onStep: (id, s) {
          if (s.state == ImportStepState.done) steps.add(id);
        },
      );
      expect(result.failed, 0);
      // The upgrade replaced a loaded bundle: restart to apply, though `applied`.
      expect(result.needsRestart, isTrue);
      expect(result.statuses['plugin:dsh-notes']!.message, '重启后生效');
      expect(result.statuses['plugin:dsh-writer']!.message, isNull);
      expect(steps, [
        'plugin:dsh-notes',
        'plugin:dsh-writer',
        'plugin:@deepseek-ai/dsh-experimental-session-titles-bundle',
        'preset:writer',
        'settings:subagent',
      ]);
      expect(engine.argsOf('pluginManager/removeBundle').single['name'], 'dsh-notes');
      expect(engine.argsOf('pluginManager/installBundle').map((a) => a['spec']), [
        'dsh-notes@1.4.2',
        'github:acme/dsh-writer#v2.0.0',
      ]);
      expect(engine.argsOf('pluginManager/setBundleEnabled').single['enabled'], isTrue);
      expect(engine.settings['subagent']!['user'], {'maxDepth': 3});
      // cot-translation never appeared on this host: skipped, not failed.
      expect(result.statuses['settings:cot-translation']?.state, ImportStepState.skipped);

      expect(result.statuses.keys, isNot(contains('skill:outline')));
      expect(result.statuses.keys, isNot(contains('agents-md')));
    });

    test('a failed install is reported and its presets are skipped', () async {
      engine.failInstall['dsh-notes@1.4.2'] = 'network';
      final plan = await planImport(profile(), ImportTarget(_host(client), isActive: false), net: net);
      final result = await applyImport(plan, plan.defaultSelection, runner: DirectPluginRunner(client));
      expect(result.statuses['plugin:dsh-notes']!.state, ImportStepState.failed);
      expect(result.statuses['plugin:dsh-notes']!.message, isNotEmpty);
      expect(result.statuses['preset:writer']!.state, ImportStepState.skipped);
      expect(result.statuses['plugin:dsh-writer']!.state, ImportStepState.done);
    });

    test('a single plugin share is a one-row plan', () async {
      final plan = await planImport(
        PluginShare(profile().plugins.first),
        ImportTarget(_host(client), isActive: false),
        net: net,
      );
      expect(plan.changes.single.kind, ChangeKind.upgrade);
      final result = await applyImport(plan, plan.defaultSelection, runner: DirectPluginRunner(client));
      expect(result.done, 1);
    });
  });

  test('gist links fetch the code and check it', () async {
    final net = FakeShareNet();
    const share = PluginShare(SharedPlugin(name: 'x', source: PluginSourceKind.npm, spec: 'x@1.0.0', version: '1.0.0'));
    final code = encodeShareCode(share);
    final id = await net.createGist(
      token: 'good',
      fileName: 'x.dshgo',
      content: encodeShareFile(share, code: code),
    );
    final sum = code.split('.').last;
    expect(await resolveShareLink(ShareLink.gist(id, sum), net), isA<PluginShare>());
    expect(() => resolveShareLink(ShareLink.gist(id, 'AAAAAAAA'), net), throwsA(isA<ShareDecodeException>()));
    await expectLater(() => net.createGist(token: 'bad', fileName: 'x', content: ''), throwsA(isA<GistException>()));
  });
}
