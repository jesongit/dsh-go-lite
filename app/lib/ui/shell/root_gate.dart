import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../launch/launch_state.dart';
import '../../state/hosts_state.dart';
import '../../state/settings_state.dart';
import '../remote/remote_screen.dart';
import '../theme/theme.dart';
import '../web/mode_home.dart';
import 'brand_mark.dart';
import 'usage_upgrade_notice.dart';

/// Restores client preferences and the explicit host choice before showing home.
/// A fresh install or an obsolete local selection opens the connection page.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key, this.home});

  @visibleForTesting
  final Widget? home;

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  bool _hostReady = false;
  bool _launchReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(activeHostProvider.notifier).ready.then((_) {
        if (mounted) setState(() => _hostReady = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final host = ref.watch(activeHostProvider);
    if (!settings.loaded || !_hostReady) return const _Splash();
    if (!_launchReady) {
      _launchReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => LaunchController.active.value?.ready());
    }
    return UsageUpgradeNotice(child: widget.home ?? (host.isNone ? const RemoteScreen() : const ModeHome()));
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: dshSystemOverlay(Theme.of(context).brightness),
    child: AppBackdrop(
      child: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: AppMotion.of(context, AppMotion.slow),
          child: const BrandMark(size: 64, tile: true),
        ),
      ),
    ),
  );
}
