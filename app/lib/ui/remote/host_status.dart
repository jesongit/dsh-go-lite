import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/connection_state.dart';
import '../../state/hosts_state.dart';
import '../common/status_dot.dart';
import '../theme/app_icons.dart';

/// Dot + words for a host's state. Colour is never the only signal.
class HostStatusView {
  const HostStatusView(this.tone, this.label);

  final StatusTone tone;
  final String label;

  static HostStatusView ofLink(HostLinkStatus status) => switch (status.phase) {
    HostLinkPhase.idle => HostStatusView(StatusTone.idle, appL10n.commonNotConnected),
    HostLinkPhase.connecting => HostStatusView(
      StatusTone.busy,
      status.step == null ? appL10n.remoteConnecting : '${status.step!.label}…',
    ),
    HostLinkPhase.connected => HostStatusView(StatusTone.ok, appL10n.remoteConnected),
    HostLinkPhase.reconnecting => HostStatusView(StatusTone.warn, appL10n.remoteReconnecting),
    HostLinkPhase.failed => HostStatusView(StatusTone.error, appL10n.commonConnectionFailed),
  };

  static HostStatusView ofRelayHost(RelayHost host) => host.online
      ? HostStatusView(StatusTone.ok, appL10n.remoteOnline)
      : HostStatusView(StatusTone.idle, appL10n.remoteOffline);
}

/// Live status of [host]: the engine for 本机, the link for remote hosts.
HostStatusView watchHostStatus(WidgetRef ref, HostRef host) {
  if (host.kind == HostKind.none) return HostStatusView(StatusTone.idle, appL10n.commonNotConnected);
  final status = ref.watch(hostLinkStatusProvider(host)).value ?? HostLinkStatus.idle;
  return HostStatusView.ofLink(status);
}

IconData hostKindIcon(HostKind kind) => switch (kind) {
  HostKind.none => AppIcons.remoteHosts,
  HostKind.ssh => AppIcons.sshHost,
  HostKind.relay => AppIcons.computer,
};

/// Identity tint per kind (one of the 8 fixed pairs), so rows read as a set.
int hostKindTint(HostKind kind) => switch (kind) {
  HostKind.none => 0,
  HostKind.ssh => 6,
  HostKind.relay => 1,
};
