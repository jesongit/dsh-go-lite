import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notify/chat_alerts.dart';
import '../notify/answer_native_request.dart';
import '../notify/request_answer.dart';
import '../notify/notify_channel.dart';
import '../pets/pet_signals.dart' show petHearAlert, petOnScreenProvider;
import 'bots_state.dart';
import 'chat_state.dart';
import 'connection_state.dart';
import 'hosts_state.dart';
import 'sessions_state.dart';

export '../notify/chat_alerts.dart';
export '../notify/notify_channel.dart';

final notifyChannelProvider = Provider<NotifyChannel>((ref) => NotifyChannel());

// ── Settings ─────────────────────────────────────────────────────────────────

/// 设置 → 通知: a master switch plus one per kind of event.
class NotifyPrefs {
  const NotifyPrefs({
    this.enabled = true,
    this.done = true,
    this.failed = true,
    this.approval = true,
    this.question = true,
    this.live = true,
    this.loaded = false,
  });

  final bool enabled;

  /// 一轮正常完成.
  final bool done;

  /// 一轮出错或被停下.
  final bool failed;

  /// 等你确认（审批）.
  final bool approval;

  /// 向你提问.
  final bool question;

  /// 实时活动: the status bar chip / island while DSH works (lib/notify/live_activity.dart).
  final bool live;
  final bool loaded;

  bool allows(AlertKind kind) =>
      enabled &&
      switch (kind) {
        AlertKind.done => done,
        AlertKind.failed || AlertKind.stopped => failed,
        AlertKind.approval => approval,
        AlertKind.question => question,
      };

  NotifyPrefs copyWith({
    bool? enabled,
    bool? done,
    bool? failed,
    bool? approval,
    bool? question,
    bool? live,
    bool? loaded,
  }) => NotifyPrefs(
    enabled: enabled ?? this.enabled,
    done: done ?? this.done,
    failed: failed ?? this.failed,
    approval: approval ?? this.approval,
    question: question ?? this.question,
    live: live ?? this.live,
    loaded: loaded ?? this.loaded,
  );
}

class NotifyPrefsController extends Notifier<NotifyPrefs> {
  static const _keys = (
    enabled: 'notify_enabled',
    done: 'notify_done',
    failed: 'notify_failed',
    approval: 'notify_approval',
    question: 'notify_question',
    live: 'notify_live',
  );

  late Future<void> _loaded;

  @override
  NotifyPrefs build() {
    _loaded = _load();
    return const NotifyPrefs();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = NotifyPrefs(
        enabled: prefs.getBool(_keys.enabled) ?? true,
        done: prefs.getBool(_keys.done) ?? true,
        failed: prefs.getBool(_keys.failed) ?? true,
        approval: prefs.getBool(_keys.approval) ?? true,
        question: prefs.getBool(_keys.question) ?? true,
        live: prefs.getBool(_keys.live) ?? true,
        loaded: true,
      );
    } catch (_) {
      // No preferences backend (tests): defaults, all on.
      state = state.copyWith(loaded: true);
    }
  }

  /// Applies after the stored values are in, so a load finishing late can't
  /// undo a switch flipped right after launch.
  Future<void> _save(String key, bool value, NotifyPrefs Function(NotifyPrefs) apply) async {
    await _loaded;
    state = apply(state);
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {
      // Kept for this run only.
    }
  }

  Future<void> setEnabled(bool v) => _save(_keys.enabled, v, (s) => s.copyWith(enabled: v));
  Future<void> setDone(bool v) => _save(_keys.done, v, (s) => s.copyWith(done: v));
  Future<void> setFailed(bool v) => _save(_keys.failed, v, (s) => s.copyWith(failed: v));
  Future<void> setApproval(bool v) => _save(_keys.approval, v, (s) => s.copyWith(approval: v));
  Future<void> setQuestion(bool v) => _save(_keys.question, v, (s) => s.copyWith(question: v));
  Future<void> setLive(bool v) => _save(_keys.live, v, (s) => s.copyWith(live: v));
}

final notifyPrefsProvider = NotifierProvider<NotifyPrefsController, NotifyPrefs>(NotifyPrefsController.new);

/// What the system allows; re-read with `ref.invalidate` (the settings page
/// does on resume, after the person may have changed it).
final notifySystemStatusProvider = FutureProvider<NotifySystemStatus>(
  (ref) => ref.watch(notifyChannelProvider).status(),
);

// ── Where the person is looking ──────────────────────────────────────────────

/// A simple settable flag (set by [ChatAlertHost] in the UI).
class FlagController extends Notifier<bool> {
  FlagController(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) {
    if (value != state) state = value;
  }
}

/// The app is on screen (resumed or briefly inactive, e.g. the notification
/// shade is down). Set from the app lifecycle by the alert host.
final appForegroundProvider = NotifierProvider<FlagController, bool>(() => FlagController(true));

/// The chat is the current route (no settings page or sheet pushed over it).
final chatOnScreenProvider = NotifierProvider<FlagController, bool>(() => FlagController(true));

/// Something asked for the person's attention unbidden in this launch (the
/// usage statistics toast, an update offer, the background running line):
/// the star prompt waits for another launch.
final launchNoticeShownProvider = NotifierProvider<FlagController, bool>(() => FlagController(false));

/// A conversation on a host.
typedef ChatTarget = ({HostRef host, String sessionId});

/// The conversation the person is looking at right now, or null.
final viewedChatProvider = Provider<ChatTarget?>((ref) {
  if (!ref.watch(appForegroundProvider) || !ref.watch(chatOnScreenProvider)) return null;
  final session = ref.watch(currentSessionProvider);
  final host = ref.watch(activeHostProvider);
  if (session == null || host.isNone) return null;
  return (host: host, sessionId: session);
});

// ── Delivery ─────────────────────────────────────────────────────────────────

/// Where a connected host's alerts come from (tests swap in a fake).
final alertSourceFactoryProvider = Provider<AlertSource Function(HostConnection connection)>(
  (ref) =>
      (connection) => DshAlertSource(connection.client),
);

/// How long a request waits before alerting, and how long after a reconnect
/// the Host gets to redeliver what is still pending.
final alertTimingProvider = Provider<({Duration announce, Duration reconcile})>(
  (ref) => (announce: const Duration(milliseconds: 800), reconcile: const Duration(seconds: 3)),
);

enum AlertDelivery { none, banner, pet, system }

/// System notification in the background, a banner in the foreground — or
/// the pet's bubble when it is on screen ([petOnScreen]: one reminder, not
/// two) — and nothing for the conversation already on screen.
AlertDelivery deliveryFor(
  ChatAlert alert, {
  required NotifyPrefs prefs,
  required bool foreground,
  ChatTarget? viewed,
  bool petOnScreen = false,
}) {
  if (!prefs.allows(alert.kind)) return AlertDelivery.none;
  if (viewed != null && viewed.host == alert.host && viewed.sessionId == alert.sessionId) return AlertDelivery.none;
  if (!foreground) return AlertDelivery.system;
  return petOnScreen ? AlertDelivery.pet : AlertDelivery.banner;
}

NotifyPost postFor(ChatAlert alert) => NotifyPost(
  group: notifyGroup(alert.host, alert.sessionId),
  key: alert.key,
  attention: alert.kind.attention,
  title: alert.title,
  text: alert.text,
  publicText: alert.kind.publicText,
  sessionId: alert.sessionId,
  host: alert.host,
  kind: alert.kind.name,
  eventId: alert.eventId,
  canApprove: alert.canApprove,
  fullText: alert.fullText,
);

/// Watches the active remote host for alerts, posts system notifications or
/// raises the in-app banner, and clears what the person has seen.
///
/// Alerts arrive only while the app process lives and the link is up.
class ChatAlertsController extends Notifier<ChatAlert?> {
  final Map<HostRef, (HostConnection, HostAlertTracker)> _trackers = {};
  Object _lifetime = Object();

  /// False while [build] runs (listeners fire immediately, before there is a
  /// state to read or replace).
  bool _built = false;
  StreamSubscription<NotifyAction>? _actions;

  NotifyChannel get _channel => ref.read(notifyChannelProvider);

  ChatAlert? get _banner => _built ? state : null;

  set _banner(ChatAlert? value) {
    if (_built) state = value;
  }

  @override
  ChatAlert? build() {
    _built = false;
    _lifetime = Object();
    final channel = _channel;
    unawaited(() async {
      if (!(await channel.status()).native || !ref.mounted) return;
      _actions = channel.actions.listen((action) async {
        await channel.completeAction(action, await respondAction(action));
      });
    }());
    ref.onDispose(() {
      _lifetime = Object();
      unawaited(_actions?.cancel());
      for (final (_, tracker) in _trackers.values) {
        unawaited(tracker.dispose());
      }
      _trackers.clear();
    });
    ref.listen(activeConnectionProvider, (_, next) {
      final conn = next.value;
      final host = conn == null ? null : _remoteRef(conn);
      for (final other in [..._trackers.keys]) {
        if (other != host) _attach(other, null);
      }
      if (host != null) _attach(host, conn);
    }, fireImmediately: true);
    ref.listen(viewedChatProvider, (_, viewed) {
      if (viewed != null) _seen(viewed);
    }, fireImmediately: true);
    ref.listen(notifyPrefsProvider.select((p) => p.enabled), (was, enabled) {
      // Switched off: what is already in the shade goes too.
      if (was == true && !enabled) {
        _banner = null;
        unawaited(_channel.cancelAll());
      }
    });
    ref.listen(appForegroundProvider, (_, foreground) {
      // Leaving the app with a banner up: keep it as a notification.
      final banner = _banner;
      if (!foreground && banner != null) {
        _banner = null;
        unawaited(_channel.show(postFor(banner)));
      }
    });
    _built = true;
    return null;
  }

  /// Answers the approval behind a tapped notification button on its host.
  Future<NotifyActionResult> respondAction(NotifyAction action) async {
    final attached = _trackers[action.host];
    if (attached == null || !attached.$2.source.connected) return NotifyActionResult.failed;
    final request = attached.$2.approvalFor(action.eventId);
    if (request == null) return NotifyActionResult.gone;
    try {
      await attached.$1.client.respondApproval(request, action.decision);
      return NotifyActionResult.handled;
    } catch (_) {
      return NotifyActionResult.failed;
    }
  }

  /// Answers a request from the floating pet's bubble, the way the
  /// notification's buttons do: an approval only if the bubble showed all of
  /// it ([HostAlertTracker.petApprovalFor]) and only allow once / reject; a
  /// question only with one of its own choices ([petChoices]).
  Future<NotifyActionResult> answerFromPet(
    HostRef host,
    String eventId, {
    required String sessionId,
    required int token,
    ApprovalDecision? decision,
    String? choice,
  }) async {
    final attached = _trackers[host];
    if (attached == null || !attached.$2.source.connected) return NotifyActionResult.failed;
    final generation = attached.$1.client.mux.generation;
    final lifetime = _lifetime;
    bool current() =>
        ref.mounted &&
        identical(_lifetime, lifetime) &&
        identical(_trackers[host]?.$2, attached.$2) &&
        attached.$2.petRequestMatches(eventId, sessionId, token);
    if (!current()) return NotifyActionResult.gone;
    if (generation == null) return NotifyActionResult.failed;
    try {
      if (decision != null) {
        if (decision != ApprovalDecision.allowOnce && decision != ApprovalDecision.reject) {
          return NotifyActionResult.failed;
        }
        final request = attached.$2.petApprovalFor(eventId);
        if (request == null) {
          return attached.$2.approvalFor(eventId) == null ? NotifyActionResult.gone : NotifyActionResult.failed;
        }
        final sent = await answerRequestApproval(
          client: attached.$1.client,
          generation: generation,
          request: request,
          decision: decision,
          current: current,
        );
        return sent ? NotifyActionResult.handled : NotifyActionResult.gone;
      }
      final request = attached.$2.questionFor(eventId);
      if (request == null) return NotifyActionResult.gone;
      final choices = petChoices(request);
      if (choice == null || choices == null || !choices.contains(choice)) return NotifyActionResult.failed;
      final sent = await answerNativeRequest(
        client: attached.$1.client,
        generation: generation,
        eventId: request.eventId,
        outcome: {
          'kind': 'result',
          'value': {
            'answers': [
              QuestionAnswer(request.questions.single.id, selected: [choice]).toJson(),
            ],
          },
        },
        current: current,
      );
      return sent ? NotifyActionResult.handled : NotifyActionResult.gone;
    } catch (_) {
      return NotifyActionResult.failed;
    }
  }

  /// The remote host a connection belongs to; null without a selected host.
  HostRef? _remoteRef(HostConnection connection) {
    final id = connection.hostId;
    if (id == null) return null;
    final active = ref.read(activeHostProvider);
    return switch (connection.kind) {
      HostKind.none => null,
      HostKind.ssh => HostRef.ssh(id),
      HostKind.relay => HostRef.relay(id, name: active.id == id ? active.name : null),
    };
  }

  void _attach(HostRef host, HostConnection? connection) {
    final current = _trackers[host];
    if (current != null && identical(current.$1.client, connection?.client)) return;
    if (current != null) {
      _trackers.remove(host);
      unawaited(current.$2.dispose());
    }
    if (connection == null) return;
    final timing = ref.read(alertTimingProvider);
    final tracker = HostAlertTracker(
      host: host,
      source: ref.read(alertSourceFactoryProvider)(connection),
      onAlert: _onAlert,
      onWithdraw: _onWithdraw,
      onSessionGone: _onSessionGone,
      skipApproval: (sessionId) => ref.exists(chatProvider(sessionId)) && ref.read(chatProvider(sessionId)).autoApprove,
      announceDelay: timing.announce,
      reconcileDelay: timing.reconcile,
    );
    _trackers[host] = (connection, tracker);
    tracker.start();
  }

  void _onAlert(ChatAlert alert) => _deliver(alert);

  void _deliver(ChatAlert alert) {
    // DS Bot's own conversations: it sends its own notifications.
    if (ref.read(dsBotSessionFilterProvider)(alert.host, alert.sessionId)) return;
    final prefs = ref.read(notifyPrefsProvider);
    final foreground = ref.read(appForegroundProvider);
    final delivery = deliveryFor(
      alert,
      prefs: prefs,
      foreground: foreground,
      viewed: ref.read(viewedChatProvider),
      petOnScreen: ref.read(petOnScreenProvider),
    );
    // The pet hears every alert (it moves for the one on screen too); it
    // speaks up for those that would have reached the person.
    petHearAlert(ref, alert, bubble: delivery == AlertDelivery.pet || delivery == AlertDelivery.system);
    switch (delivery) {
      case AlertDelivery.none || AlertDelivery.pet:
        return;
      case AlertDelivery.banner:
        _banner = alert;
      case AlertDelivery.system:
        unawaited(_channel.show(postFor(alert)));
    }
  }

  void _onWithdraw(HostRef host, String sessionId, String key) {
    unawaited(_channel.cancel(notifyGroup(host, sessionId), key));
    final banner = _banner;
    if (banner != null && banner.host == host && banner.sessionId == sessionId && banner.key == key) _banner = null;
  }

  void _onSessionGone(HostRef host, String sessionId) {
    _clearSessionNotifications(host, sessionId);
  }

  void _clearSessionNotifications(HostRef host, String sessionId) {
    unawaited(_channel.cancelGroup(notifyGroup(host, sessionId)));
    final banner = _banner;
    if (banner != null && banner.host == host && banner.sessionId == sessionId) _banner = null;
  }

  /// The person is looking at [chat]: its notifications and banner are moot.
  void _seen(ChatTarget chat) => _clearSessionNotifications(chat.host, chat.sessionId);

  /// Hides [alert]'s banner (timeout or swipe); a newer banner stays.
  void dismissBanner(ChatAlert alert) {
    if (identical(_banner, alert)) _banner = null;
  }

  /// Opens [sessionId] on [host] (a tapped notification or banner).
  void open(HostRef host, String sessionId) {
    if (host.isNone) return;
    // Always select: it also stops a still-pending restore of the last host
    // from switching away again on a cold start.
    ref.read(activeHostProvider.notifier).select(host);
    ref.read(currentSessionProvider.notifier).select(sessionId);
  }
}

final chatAlertsProvider = NotifierProvider<ChatAlertsController, ChatAlert?>(ChatAlertsController.new);
