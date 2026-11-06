// Where alerts go (system notification, banner, nothing), what gets cleared,
// and how a tap opens the conversation (lib/state/notify_state.dart).

import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_app/state/notify_state.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';
import '../support/remote_hosts.dart';

const _ssh = HostRef.ssh('lab');

ChatAlert _alert(String session, AlertKind kind, {HostRef host = const HostRef.ssh('primary'), String key = turnKey}) =>
    ChatAlert(host: host, sessionId: session, kind: kind, key: key, title: 't', text: 'x');

void main() {
  group('deliveryFor', () {
    const prefs = NotifyPrefs();
    final done = _alert('s1', AlertKind.done);

    test('background → system, foreground → banner', () {
      expect(deliveryFor(done, prefs: prefs, foreground: false), AlertDelivery.system);
      expect(deliveryFor(done, prefs: prefs, foreground: true), AlertDelivery.banner);
    });

    test('the conversation on screen is never interrupted', () {
      expect(
        deliveryFor(done, prefs: prefs, foreground: true, viewed: (host: HostRef.ssh('primary'), sessionId: 's1')),
        AlertDelivery.none,
      );
      // Same id on another host is another conversation.
      expect(
        deliveryFor(done, prefs: prefs, foreground: true, viewed: (host: _ssh, sessionId: 's1')),
        AlertDelivery.banner,
      );
    });

    test('settings: master switch and one switch per kind', () {
      expect(deliveryFor(done, prefs: const NotifyPrefs(enabled: false), foreground: false), AlertDelivery.none);
      expect(deliveryFor(done, prefs: const NotifyPrefs(done: false), foreground: false), AlertDelivery.none);
      final stopped = _alert('s1', AlertKind.stopped);
      expect(deliveryFor(stopped, prefs: const NotifyPrefs(failed: false), foreground: false), AlertDelivery.none);
      expect(deliveryFor(stopped, prefs: const NotifyPrefs(done: false), foreground: false), AlertDelivery.system);
      final ask = _alert('s1', AlertKind.question);
      expect(deliveryFor(ask, prefs: const NotifyPrefs(approval: false), foreground: false), AlertDelivery.system);
      expect(deliveryFor(ask, prefs: const NotifyPrefs(question: false), foreground: false), AlertDelivery.none);
    });
  });

  test('postFor: grouping, channel and lock-screen text', () {
    final post = postFor(
      const ChatAlert(
        host: _ssh,
        sessionId: 's9',
        kind: AlertKind.approval,
        key: 'e1',
        title: '部署',
        text: '等你确认：运行命令',
        eventId: 'e1',
      ),
    );
    expect(post.group, 'ssh:lab|s9');
    expect(post.attention, isTrue);
    expect(post.canApprove, isFalse);
    expect(post.publicText, '有一步等你确认');
    expect(post.toMap(), containsPair('host', _ssh.encode()));
    expect(post.toMap(), containsPair('eventId', 'e1'));
    expect(postFor(_alert('s1', AlertKind.done)).attention, isFalse);
    expect(postFor(_alert('s1', AlertKind.done)).toMap().containsKey('eventId'), isFalse);
  });

  test('postFor carries verified approval details without changing older callers', () {
    final post = postFor(
      const ChatAlert(
        host: _ssh,
        sessionId: 's9',
        kind: AlertKind.approval,
        key: 'e1',
        eventId: 'e1',
        title: '部署',
        text: '运行：echo ok',
        fullText: '运行：echo ok',
        canApprove: true,
      ),
    );
    expect(post.canApprove, isTrue);
    expect(post.toMap(), containsPair('canApprove', true));
    expect(post.fullText, '运行：echo ok');
  });

  group('NotifyTap.fromMap', () {
    test('parses our payload', () {
      final tap = NotifyTap.fromMap({'sessionId': 's1', 'host': _ssh.encode(), 'kind': 'approval', 'eventId': 'e1'});
      expect(tap, const NotifyTap(host: _ssh, sessionId: 's1', kind: 'approval', eventId: 'e1'));
    });

    test('rejects missing, legacy local and malformed hosts', () {
      for (final host in [null, '', '{}', 'bad', '{"kind":"local","id":"local"}', HostRef.none.encode()]) {
        expect(NotifyTap.fromMap({'sessionId': 's1', 'host': host}), isNull);
      }
      expect(NotifyTap.fromMap({'sessionId': ''}), isNull);
      expect(NotifyTap.fromMap({'host': 'x'}), isNull);
      expect(NotifyTap.fromMap('s1'), isNull);
      expect(NotifyTap.fromMap({'sessionId': 'x' * 300}), isNull);
    });
  });

  group('controller', () {
    late FakeNotifyChannel channel;
    late FakeAlertSource primary;
    late FakeAlertSource remote;
    late ProviderContainer container;
    late List<Override> overrides;

    ProviderContainer make({HostConnection? active}) {
      final primaryConnection = fakeHostConnection();
      container = ProviderContainer(
        overrides: overrides = [
          notifyChannelProvider.overrideWithValue(channel),
          alertSourceFactoryProvider.overrideWithValue((conn) => conn.hostId == 'primary' ? primary : remote),
          alertTimingProvider.overrideWithValue((announce: Duration.zero, reconcile: const Duration(milliseconds: 30))),
          activeHostProvider.overrideWith(() => FixedActiveHost(active == null ? const HostRef.ssh('primary') : _ssh)),
          activeConnectionProvider.overrideWithValue(AsyncData(active ?? primaryConnection)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(chatAlertsProvider, (_, _) {});
      return container;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      channel = FakeNotifyChannel();
      primary = FakeAlertSource()..sessions = [session('s1', title: '修复登录按钮'), session('s2', title: '深色模式')];
      remote = FakeAlertSource()..sessions = [session('r1', title: '服务器上的任务')];
    });

    Future<void> foreground(bool value) async {
      container.read(appForegroundProvider.notifier).set(value);
      await settle();
    }

    test('in the background: a system notification', () async {
      make();
      await settle();
      await foreground(false);
      primary.emit(approval('e1', 's1'));
      await settle();
      expect(channel.shown, hasLength(1));
      final post = channel.shown.single;
      expect(post.group, 'ssh:primary|s1');
      expect(post.key, 'e1');
      expect(post.attention, isTrue);
      expect(post.title, '修复登录按钮');
      expect(post.publicText, '有一步等你确认');
      expect(container.read(chatAlertsProvider), isNull);
    });

    test('in the foreground on another conversation: a banner', () async {
      make();
      await settle();
      container.read(currentSessionProvider.notifier).select('s2');
      await settle();
      primary.emit(question('q1', 's1', ['继续吗？']));
      await settle();
      expect(channel.shown, isEmpty);
      expect(container.read(chatAlertsProvider)?.sessionId, 's1');
    });

    test('on the conversation itself: nothing', () async {
      make();
      await settle();
      container.read(currentSessionProvider.notifier).select('s1');
      await settle();
      primary.emit(approval('e1', 's1'));
      await settle();
      expect(channel.shown, isEmpty);
      expect(container.read(chatAlertsProvider), isNull);
    });

    test('a page over the chat counts as not looking: banner', () async {
      make();
      await settle();
      container.read(currentSessionProvider.notifier).select('s1');
      container.read(chatOnScreenProvider.notifier).set(false);
      await settle();
      primary.emit(approval('e1', 's1'));
      await settle();
      expect(container.read(chatAlertsProvider)?.key, 'e1');
    });

    test('opening the conversation clears its notifications and banner', () async {
      make();
      await settle();
      primary.emit(approval('e1', 's1'));
      await settle();
      expect(container.read(chatAlertsProvider), isNotNull);
      container.read(chatAlertsProvider.notifier).open(HostRef.ssh('primary'), 's1');
      await settle();
      expect(container.read(currentSessionProvider), 's1');
      expect(channel.cancelledGroups, contains('ssh:primary|s1'));
      expect(container.read(chatAlertsProvider), isNull);
    });

    test('answered elsewhere: notification and banner withdrawn', () async {
      make();
      await settle();
      primary.emit(approval('e1', 's1'));
      await settle();
      primary.emit(const HostRequestCancelledEvent('e1'));
      await settle();
      expect(channel.cancelled, [('ssh:primary|s1', 'e1')]);
      expect(container.read(chatAlertsProvider), isNull);
    });

    test('leaving the app with a banner up keeps it as a notification', () async {
      make();
      await settle();
      primary.emit(approval('e1', 's2'));
      await settle();
      expect(container.read(chatAlertsProvider), isNotNull);
      await foreground(false);
      expect(container.read(chatAlertsProvider), isNull);
      expect(channel.shown.single.key, 'e1');
    });

    test('settings off: nothing at all', () async {
      make();
      await settle();
      await container.read(notifyPrefsProvider.notifier).setEnabled(false);
      expect(channel.cancelledAll, 1, reason: 'switching off clears the shade');
      await foreground(false);
      primary.emit(approval('e1', 's1'));
      await settle();
      expect(channel.shown, isEmpty);
    });

    test('a newer banner replaces the older; dismissing an old one is a no-op', () async {
      make();
      await settle();
      primary.emit(approval('e1', 's1'));
      await settle();
      final first = container.read(chatAlertsProvider)!;
      primary.emit(approval('e2', 's2'));
      await settle();
      final second = container.read(chatAlertsProvider)!;
      expect(second.key, 'e2');
      container.read(chatAlertsProvider.notifier).dismissBanner(first);
      expect(container.read(chatAlertsProvider), same(second));
      container.read(chatAlertsProvider.notifier).dismissBanner(second);
      expect(container.read(chatAlertsProvider), isNull);
    });

    test('switching remote hosts retires the previous tracker', () async {
      make();
      await settle();
      await foreground(false);
      primary.emit(approval('e1', 's1'));
      await settle();
      container.updateOverrides([
        ...overrides.where((o) => o.origin != activeConnectionProvider),
        activeConnectionProvider.overrideWithValue(AsyncData(fakeHostConnection(kind: HostKind.ssh, hostId: 'lab'))),
      ]);
      await settle();
      primary.emit(approval('old', 's1'));
      remote.emit(approval('e9', 'r1'));
      await settle();
      expect(channel.shown.map((p) => p.group), ['ssh:primary|s1', 'ssh:lab|r1']);
      container.read(chatAlertsProvider.notifier).open(_ssh, 'r1');
      expect(container.read(activeHostProvider), _ssh);
      expect(container.read(currentSessionProvider), 'r1');
    });
  });

  group('NotifyPrefs', () {
    test('defaults on, persisted, and a flip right after launch survives the load', () async {
      SharedPreferences.setMockInitialValues({'notify_question': false});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(notifyPrefsProvider.notifier).setDone(false);
      final prefs = c.read(notifyPrefsProvider);
      expect(prefs.loaded, isTrue);
      expect(prefs.enabled, isTrue);
      expect(prefs.done, isFalse);
      expect(prefs.question, isFalse);
      expect((await SharedPreferences.getInstance()).getBool('notify_done'), isFalse);
    });
  });

  group('viewedChatProvider', () {
    test('no selected host cannot view or open a conversation', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          activeHostProvider.overrideWith(() => FixedActiveHost(HostRef.none)),
          activeConnectionProvider.overrideWithValue(const AsyncData(null)),
          notifyChannelProvider.overrideWithValue(FakeNotifyChannel()),
        ],
      );
      addTearDown(c.dispose);
      c.read(currentSessionProvider.notifier).select('stale-session');
      expect(c.read(viewedChatProvider), isNull);
      c.read(chatAlertsProvider.notifier).open(HostRef.none, 'another-session');
      expect(c.read(activeHostProvider), HostRef.none);
      expect(c.read(currentSessionProvider), 'stale-session');
    });

    test('needs the app and the chat on screen and an open conversation', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [activeHostProvider.overrideWith(() => FixedActiveHost(const HostRef.ssh('primary')))],
      );
      addTearDown(c.dispose);
      expect(c.read(viewedChatProvider), isNull, reason: 'new chat');
      c.read(currentSessionProvider.notifier).select('s1');
      expect(c.read(viewedChatProvider), (host: HostRef.ssh('primary'), sessionId: 's1'));
      c.read(appForegroundProvider.notifier).set(false);
      expect(c.read(viewedChatProvider), isNull);
      c.read(appForegroundProvider.notifier).set(true);
      c.read(chatOnScreenProvider.notifier).set(false);
      expect(c.read(viewedChatProvider), isNull);
    });
  });
}
