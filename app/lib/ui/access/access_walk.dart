// One item at a time: why in a line, one key to where it is turned on, a
// check when the person comes back with it on. First run walks everything
// the picked features need; 设置 › 系统权限 walks one item.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/access_state.dart';
import '../onboarding/onboarding_scaffold.dart';
import '../theme/theme.dart';
import 'access_text.dart';
import 'access_widgets.dart';

/// Coming back to the app reads everything again: an item that is on now
/// shows its check and moves along. A maker's switch can't be read, so after
/// the trip the person says 「设好了」 (shown as 「已去设置」, never as on).
class AccessWalk extends ConsumerStatefulWidget {
  const AccessWalk({
    super.key,
    required this.items,
    required this.onDone,
    this.skipped = const {},
    this.onSkip,
    this.leading,
    this.vendor,
    this.revisit = false,
  });

  /// In walk order; ones already settled are passed over.
  final List<AccessItem> items;

  /// Skipped earlier (first run, before the app went away).
  final Set<AccessItem> skipped;
  final ValueChanged<AccessItem>? onSkip;

  /// Every item is settled or skipped.
  final VoidCallback onDone;

  /// Top-left key (back, when opened from settings).
  final Widget? leading;

  /// The phone's maker, for the names of its switches.
  final String? vendor;

  /// A maker's switch already visited is shown again (opened from its row)
  /// rather than passed over.
  final bool revisit;

  /// How long the check shows before the next item.
  static const doneHold = Duration(milliseconds: 700);

  @override
  ConsumerState<AccessWalk> createState() => _AccessWalkState();
}

class _AccessWalkState extends ConsumerState<AccessWalk> {
  late final AppLifecycleListener _lifecycle;
  late final Set<AccessItem> _skipped = {...widget.skipped};

  AccessItem? _current;

  /// Sent out to a dialog or settings page, not back yet.
  bool _away = false;

  /// Tried once, and how many times.
  final _tries = <AccessItem, int>{};

  /// Came on, or said to be set, during this walk.
  final _finishedItems = <AccessItem>{};

  /// The item that just came on, showing its check.
  AccessItem? _done;
  Timer? _doneTimer;
  bool _finished = false;

  /// 「受限制的设置」 was seen standing in the way during this walk.

  AccessDriver get _driver => ref.read(accessDriverProvider);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_onResume()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advance();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _doneTimer?.cancel();
    super.dispose();
  }

  AccessState? _stateOf(AccessItem item, AccessReadings r) => accessStateOf(item, r, ref.read(accessVisitedProvider));

  /// The next item that needs the person, or done.
  void _advance() {
    final r = ref.read(accessReadingsProvider).value;
    if (r == null) return;
    bool open(AccessItem i) => switch (_stateOf(i, r)) {
      null || AccessState.on => false,
      AccessState.visited => widget.revisit,
      AccessState.off || AccessState.unknown => true,
    };
    final next = widget.items.where((i) => !_skipped.contains(i) && !_finishedItems.contains(i) && open(i)).firstOrNull;
    if (next == null) {
      if (_finished) return;
      _finished = true;
      widget.onDone();
      return;
    }
    if (next != _current) {
      setState(() {
        _current = next;
        _done = null;
      });
    }
  }

  Future<void> _onResume() async {
    final wasAway = _away;
    _away = false;
    final r = await ref.read(accessReadingsProvider.notifier).refresh();
    if (!mounted) return;
    final item = _current;
    if (wasAway && item != null && _stateOf(item, r) == AccessState.on) _celebrate(item);
    setState(() {});
  }

  /// [item] is on: its check, then the next.
  void _celebrate(AccessItem item) {
    if (_done == item) return;
    _finishedItems.add(item);
    setState(() => _done = item);
    _doneTimer?.cancel();
    _doneTimer = Timer(
      AppMotion.of(context, AccessWalk.doneHold) == Duration.zero ? Duration.zero : AccessWalk.doneHold,
      () {
        if (mounted) _advance();
      },
    );
  }

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _go(AccessItem item, {bool appInfo = false}) async {
    final again = (_tries[item] ?? 0) > 0;
    setState(() {
      _away = true;
      _tries[item] = (_tries[item] ?? 0) + 1;
    });
    final opened = appInfo ? await _driver.openAppInfo() : await _driver.open(item, again: again);
    if (!mounted) return;
    if (!opened) {
      setState(() => _away = false);
      _toast(context.l10n.accessOpenFailed);
      return;
    }
    // A system dialog answers when the call returns.
    if (item.dialog) await _onResume();
  }

  Future<void> _confirmVendor(AccessItem item) async {
    await ref.read(accessVisitedProvider.notifier).mark(item);
    if (mounted) _celebrate(item);
  }

  void _skip(AccessItem item) {
    _doneTimer?.cancel();
    _skipped.add(item);
    widget.onSkip?.call(item);
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final readings = ref.watch(accessReadingsProvider).value;
    ref.watch(accessVisitedProvider);
    // Readings that turn the item on (from the trip, or by any other way).
    ref.listen(accessReadingsProvider, (_, next) {
      final r = next.value;
      final item = _current;
      if (r == null || item == null || _away) return;
      if (_stateOf(item, r) == AccessState.on) _celebrate(item);
    });
    final item = _current;
    if (readings == null || item == null) {
      // The first readings came after the first frame: start now.
      if (readings != null && !_finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _current == null) _advance();
        });
      }
      return OnboardingScaffold(leading: widget.leading, children: const [SizedBox.shrink()]);
    }
    final state = _stateOf(item, readings);
    final done = _done == item || state == AccessState.on;
    final tries = _tries[item] ?? 0;
    final counter = widget.items.length > 1
        ? l10n.accessStepCount(widget.items.indexOf(item) + 1, widget.items.length)
        : null;
    // The line under the reason: what came of the last trip.
    final String? status;
    Color? statusColor;
    if (done) {
      status = item.vendor ? l10n.accessStateVisited : l10n.accessIsOn;
      statusColor = theme.colorScheme.primary;
    } else if (item.vendor && tries > 0) {
      status = l10n.accessDidYouSet;
    } else if (tries > 0 && !_away) {
      status = l10n.accessNotOnYet;
      statusColor = colors.warning;
    } else {
      status = null;
    }
    final path = item.path(l10n, vendor: widget.vendor ?? readings.vendor, app: readings.appLabel);

    final (String primary, VoidCallback onPrimary) = switch (item) {
      _ when item.vendor && tries > 0 => (l10n.accessItsSet, () => unawaited(_confirmVendor(item))),
      _ when item.vendor => (l10n.accessOpenSettings, () => unawaited(_go(item))),
      _ when tries > 0 => (l10n.commonRetry, () => unawaited(_go(item))),
      _ => (l10n.accessTurnOn, () => unawaited(_go(item))),
    };
    final skip = (l10n.accessSkip, () => _skip(item));
    final secondary = <(String, VoidCallback?)>[
      if (item.vendor && tries > 0) (l10n.accessOpenAgain, () => unawaited(_go(item))),
      skip,
    ];

    final textScaler = MediaQuery.textScalerOf(context);
    return OnboardingScaffold(
      leading: widget.leading,
      children: [
        const Spacer(),
        KeyedSubtree(
          key: ValueKey('access-step-${item.name}'),
          child: AccessHeader(
            icon: item.icon,
            title: item.title(l10n, vendor: widget.vendor ?? readings.vendor),
            message: item.why(l10n),
            counter: counter,
            done: done,
          ),
        ),
        if (path != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.accessWhere(path),
            key: const ValueKey('access-path'),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
        const SizedBox(height: 16),
        // The slot stays when there is nothing to say: no jump when there is.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: textScaler.scale(14) * 1.5),
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            // In line with the text above it, not centred.
            layoutBuilder: (current, previous) =>
                Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
            child: status == null
                ? const SizedBox.shrink()
                : Text(
                    status,
                    key: ValueKey(status),
                    style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
                  ),
          ),
        ),
        const Spacer(flex: 2),
        const SizedBox(height: 24),
        AccessActions(primary: primary, onPrimary: onPrimary, secondary: secondary, hidden: done),
      ],
    );
  }
}
