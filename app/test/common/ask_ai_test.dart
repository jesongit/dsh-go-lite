// 「问 AI」 (state/ask_ai.dart, ui/common/ask_ai.dart): what goes into the new
// conversation's composer on each kind of host, that every entry closes the
// pages above the chat and queues its own question, that the bar key mirrors
// the back key, and that 网页模式 shows no entry at all.

import 'dart:convert';
import 'dart:io';

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/state/ask_ai.dart';
import 'package:dsh_app/state/compose_inbox.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_app/ui/common/app_sheet.dart';
import 'package:dsh_app/ui/common/ask_ai.dart';
import 'package:dsh_app/ui/common/risk_notice.dart';
import 'package:dsh_app/ui/features/permission_page.dart';
import 'package:dsh_app/ui/settings/settings_screen.dart';
import 'package:dsh_app/ui/settings/settings_widgets.dart';
import 'package:dsh_app/ui/shell/page_frame.dart';
import 'package:dsh_app/ui/theme/app_icons.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/remote_hosts.dart' show FixedActiveHost;
import '../plugins/support/fake_plugin_host.dart';
import '../shell/golden_harness.dart';

/// The bundled guide pages, as a map (tests don't read the asset bundle).
Future<String> _pages(String asset) async => switch (asset) {
  'assets/skills/dsh-go-guide/zh-03-engine-hosts.md' => '# 远程主机\n连接电脑上的 DSH。',
  'assets/skills/dsh-go-guide/en-03-engine-hosts.md' => '# Remote hosts\nConnect to DSH on a computer.',
  'assets/skills/dsh-go-guide/zh-10-settings.md' => '# 设置',
  _ => throw StateError('no asset $asset'),
};

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what the composer gets', () {
    test('the route follows the host', () {
      expect(guideRouteFor(filesAllowed: true), GuideRoute.attachment);
      expect(guideRouteFor(filesAllowed: false), GuideRoute.none);
    });

    test('a remote host that takes files: the matching guide page rides along', () async {
      final request = await askAiRequest(AskAiTopic.remote, route: GuideRoute.attachment, read: _pages);
      expect(request.text, '关于 DSH Go App：${AskAiTopic.remote.question}\n请按附件里的使用说明回答。');
      final file = request.attachments.single;
      expect(file.name, 'dsh-go-guide-engine-hosts.md');
      expect(file.isImage, isFalse);
      expect(utf8.decode(file.bytes), '# 远程主机\n连接电脑上的 DSH。');
      expect(request.note, isNull);
    });

    test('English picks the English page', () async {
      final request = await askAiRequest(AskAiTopic.remote, route: GuideRoute.attachment, read: _pages, english: true);
      expect(utf8.decode(request.attachments.single.bytes), startsWith('# Remote hosts'));
    });

    test('a host without files, or a page that cannot be read: the question and a note', () async {
      for (final request in [
        await askAiRequest(AskAiTopic.remote, route: GuideRoute.none, read: _pages),
        await askAiRequest(AskAiTopic.plugins, route: GuideRoute.attachment, read: _pages),
      ]) {
        expect(request.text, startsWith('关于 DSH Go App：'));
        expect(request.attachments, isEmpty);
        expect(request.note, '这台主机没有 DSH Go 使用说明，回答可能不准确');
      }
    });

    test('every topic names a guide page that ships with the app', () {
      final manifest = jsonDecode(
        // Read from disk: the same file the asset bundle carries.
        File('assets/skills/dsh-go-guide/manifest.json').readAsStringSync(),
      );
      final files = (manifest as Map)['files'] as Map;
      for (final topic in AskAiTopic.values) {
        for (final english in [false, true]) {
          final asset = guidePageAsset(topic.guidePage, english: english);
          expect(files.keys, contains(asset.split('/').last), reason: '$topic → $asset');
        }
        expect(topic.question, isNotEmpty);
      }
    });
  });

  group('the bar key', () {
    Future<void> pumpPage(
      WidgetTester tester, {
      HostRef host = const HostRef.ssh('pc'),
      List<Override> overrides = const [],
    }) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        goldenApp(
          brightness: Brightness.light,
          overrides: [
            activeHostProvider.overrideWith(() => FixedActiveHost(host)),
            activeConnectionProvider.overrideWithValue(const AsyncValue.data(null)),
            guidePageReaderProvider.overrideWithValue(_pages),
            ...overrides,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppPage.list(
                        title: '远程主机',
                        actions: const [AskAiButton(AskAiTopic.remote)],
                        children: const [SizedBox(height: 400)],
                      ),
                    ),
                  ),
                  child: const Text('进入'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('进入'));
      await tester.pumpAndSettle();
    }

    testWidgets('mirrors the back key: same 44 circle, same distance from its edge', (tester) async {
      await pumpPage(tester);
      final back = tester.getRect(find.byTooltip('返回'));
      final ask = tester.getRect(find.byTooltip('问 AI'));
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(ask.size, const Size(44, 44));
      expect(ask.size, back.size);
      expect(ask.top, back.top);
      expect(width - ask.right, moreOrLessEquals(back.left, epsilon: .01));
      expect(find.descendant(of: find.byTooltip('问 AI'), matching: find.byIcon(AppIcons.askAi)), findsOneWidget);
    });

    testWidgets('closes the page and queues the question with the guide page for an SSH host', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byTooltip('问 AI'));
      await tester.pumpAndSettle();
      expect(find.byType(AppPage), findsNothing, reason: 'back at the chat');
      final request = _container(tester).read(composeInboxProvider).single;
      expect(request.text, startsWith('关于 DSH Go App：怎么连接自己的电脑或服务器？'));
      expect(request.attachments.single.name, 'dsh-go-guide-engine-hosts.md');
    });

    testWidgets('on DSH Remote, which takes no files: the question and the note', (tester) async {
      await pumpPage(tester, host: const HostRef.relay('r'));
      await tester.tap(find.byTooltip('问 AI'));
      await tester.pumpAndSettle();
      final request = _container(tester).read(composeInboxProvider).single;
      expect(request.attachments, isEmpty);
      expect(request.note, isNotNull);
    });

    testWidgets('not in 网页模式', (tester) async {
      await pumpPage(tester, overrides: [askAiAvailableProvider.overrideWithValue(false)]);
      expect(find.byTooltip('问 AI'), findsNothing);
      // The title stays centred on the bar.
      final title = tester.getRect(find.descendant(of: find.byType(NavigationToolbar), matching: find.text('远程主机')));
      expect(title.center.dx, moreOrLessEquals(195, epsilon: .5));
    });
  });

  group('设置', () {
    Future<FakeSettings> pumpSettings(WidgetTester tester, {List<Override> overrides = const []}) async {
      usePhoneSurface(tester);
      final settings = FakeSettings(const AppSettings(loaded: true));
      await tester.pumpWidget(
        goldenApp(
          home: const SettingsScreen(),
          brightness: Brightness.light,
          overrides: [
            activeHostProvider.overrideWith(() => FixedActiveHost(const HostRef.ssh('test-host'))),
            settingsProvider.overrideWith(() => settings),
            ...overrides,
          ],
        ),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('关于 › 使用帮助 asks the overview question', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('使用帮助'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final row = find.widgetWithText(SettingsTile, '使用帮助');
      expect(find.descendant(of: row, matching: find.text('问 AI')), findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        _container(tester).read(composeInboxProvider).single.text,
        startsWith('关于 DSH Go App：DSH Go 能做什么？我该从哪里开始？'),
      );
    });

    testWidgets('使用帮助 is not there in 网页模式', (tester) async {
      await pumpSettings(tester, overrides: [askAiAvailableProvider.overrideWithValue(false)]);
      await tester.scrollUntilVisible(find.text('社区'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SettingsTile, '社区'), findsOneWidget);
      expect(find.widgetWithText(SettingsTile, '使用帮助'), findsNothing);
    });
  });

  group('权限', () {
    late FakePluginCarrier carrier;
    late DshClient client;

    setUp(() {
      carrier = FakePluginCarrier();
      client = DshClient.withCarrier(carrier);
      const options = [
        {'value': 'workspace-write', 'name': 'workspace-write'},
        {'value': 'danger-full-access', 'name': 'danger-full-access'},
      ];
      carrier.handlers['settings/describe'] = (_) => {
        'writable': true,
        'namespaces': [
          {
            'ns': 'permission',
            'value': {'defaultPreset': 'workspace-write'},
            'revision': 7,
          },
        ],
      };
      carrier.handlers['settings/mutate'] = (_) => {'revision': 8};
      carrier.handlers['permissionPresets/catalog'] = (_) => {
        'options': options,
        'defaultOptions': options,
        'defaultPreset': 'workspace-write',
      };
    });
    tearDown(() => client.close());

    Future<void> pumpPermission(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        goldenApp(
          home: const PermissionPage(),
          brightness: Brightness.light,
          overrides: [
            activeHostProvider.overrideWith(() => FixedActiveHost(const HostRef.ssh('test-host'))),
            activeConnectionProvider.overrideWithValue(AsyncData(fakeHost(client))),
            settingsProvider.overrideWith(() => FakeSettings(const AppSettings(loaded: true))),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('完全权限 for new conversations asks every time; × leaves it off', (tester) async {
      await pumpPermission(tester);
      Future<void> pick() async {
        final row = find.text('完全权限');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      await pick();
      final notice = tester.widget<RiskNoticeSheet>(find.byType(RiskNoticeSheet)).notice;
      expect(notice.id, 'permission.full-access');
      expect(find.text('开启完全权限？'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(SheetHeader), matching: find.byType(SheetIconButton)));
      await tester.pumpAndSettle();
      expect(carrier.argsOf('settings/mutate'), isEmpty);

      await pick();
      await tester.tap(find.byKey(const ValueKey('risk-confirm')));
      await tester.pumpAndSettle();
      final mutation = carrier.argsOf('settings/mutate').single;
      expect(mutation['ns'], 'permission');
      expect(mutation['expectedRevision'], 7);
      expect(mutation['ops'], [
        {
          'op': 'set',
          'path': ['defaultPreset'],
          'value': 'danger-full-access',
        },
      ]);
    });
  });

  test('English questions exist for every topic', () {
    AppLocale.use(AppLocale.en);
    addTearDown(() => AppLocale.use(AppLocale.zhCN));
    for (final topic in AskAiTopic.values) {
      expect(topic.question, isNot(contains('？')), reason: '$topic');
      expect(topic.question, endsWith('?'));
    }
  });
}
