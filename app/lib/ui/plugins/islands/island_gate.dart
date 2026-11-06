import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../plugins/seams/seat_state.dart' show seatRouteGuardReportProvider;
import '../../../remote/ssh/ssh_link.dart';
import '../../../state/connection_state.dart';
import '../../../state/hosts_state.dart';

/// Whether a host's plugin routes refuse callers without the session cookie
/// (the route guard, §9).
enum RouteGuard {
  /// Not known yet, or nothing to ask (the bridge isn't installed).
  unknown,

  /// A plugin route answered a cookieless call: the hole is open.
  absent,

  /// A plugin route refused a cookieless call (401 / 403).
  present,
}

/// Whether the selected transport can serve plugin web pages (§9).
/// SSH uses the same forwarded endpoint as DSH Web. Relay has no HTTP
/// carrier, and an unselected host has no endpoint.
bool islandHostAllowed(HostKind kind) => switch (kind) {
  HostKind.relay => false,
  HostKind.ssh => true,
  HostKind.none => false,
};

/// The route that answers the probe: the bridge's own inventory, which the
/// guard covers like every other plugin route.
const routeGuardProbePath = '/dsh-go/v1/inventory';

/// Calls [routeGuardProbePath] on [base] with no cookie and no credentials.
Future<RouteGuard> probeRouteGuard(
  Uri base, {
  HttpClient? client,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final http = client ?? HttpClient();
  try {
    final url = Uri(scheme: base.scheme, host: base.host, port: base.port, path: routeGuardProbePath);
    final request = await http.getUrl(url).timeout(timeout);
    request.followRedirects = false;
    final response = await request.close().timeout(timeout);
    await response.drain<void>().catchError((_) {});
    return switch (response.statusCode) {
      401 || 403 => RouteGuard.present,
      >= 200 && < 300 => RouteGuard.absent,
      _ => RouteGuard.unknown,
    };
  } catch (_) {
    return RouteGuard.unknown;
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// What the bridge reports per host (`routeGuard`), from the seats'
/// inventory; null when unknown.
final islandRouteGuardReportProvider = Provider.family<bool?, HostRef>(
  (ref, host) => ref.watch(seatRouteGuardReportProvider(host)),
);

/// Whether the selected remote transport can serve plugin web pages.
final islandHostGateProvider = Provider.family<bool, HostRef>((ref, host) => islandHostAllowed(host.kind));

/// The DSH Web launch URL for [host]'s islands: an SSH host through the
/// app's loopback forward while connected. Relay has no web endpoint.
final islandHostUrlProvider = Provider.autoDispose.family<Uri?, HostRef>((ref, host) {
  switch (host.kind) {
    case HostKind.ssh:
      ref.watch(hostLinkStatusProvider(host));
      final link = ref.watch(hostLinkProvider(host));
      final port = link is SshHostLink ? link.localPort : null;
      final token = link is SshHostLink ? link.endpoint?.token : null;
      if (port == null || token == null) return null;
      return islandLaunchUri('http://127.0.0.1:$port', token);
    case HostKind.none:
    case HostKind.relay:
      return null;
  }
});

/// `http://127.0.0.1:3080/?token=…`: the token only buys the session cookie,
/// exactly as the 网页版 does.
Uri islandLaunchUri(String baseUrl, String token) =>
    Uri.parse(baseUrl).replace(path: '/', queryParameters: {'token': token});
