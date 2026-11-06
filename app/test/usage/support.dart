// Fakes for usage statistics: the network, device facts and lifecycle.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dsh_app/usage/usage_ledger.dart';
import 'package:dsh_app/usage/usage_net.dart';
import 'package:dsh_app/usage/usage_stats.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Records every POST; answers [reply], or throws while [offline].
class FakeUsageHttp implements UsageHttp {
  final requests = <Map<String, Object?>>[];
  final urls = <Uri>[];
  int reply = 204;
  bool offline = false;

  /// Answers for the next requests, before [reply].
  final replies = <int>[];

  List<String> get days => [for (final r in requests) r['day']! as String];

  @override
  Future<int> post(Uri url, String json, {Duration timeout = const Duration(seconds: 10)}) async {
    urls.add(url);
    requests.add(jsonDecode(json) as Map<String, Object?>);
    if (offline) throw const SocketException('offline');
    return replies.isEmpty ? reply : replies.removeAt(0);
  }
}

const testDevice = UsageDevice(app: '0.9.9', build: 10301000, sdk: 34, abi: 'arm64-v8a', maker: 'vivo');

/// Everything usage statistics reach for, faked: [clock], [http], the
/// phone, and the app coming to the front through [onResumes].
List<Override> usageOverrides({
  required DateTime Function() clock,
  required UsageHttp http,
  required void Function(VoidCallback? onResume) onResumes,
  UsageDevice device = testDevice,
  String lang = 'zh',
}) => [
  usageClockProvider.overrideWithValue(clock),
  usageHttpProvider.overrideWithValue(http),
  usageDeviceProvider.overrideWithValue(() async => device),
  usageLanguageProvider.overrideWithValue(() => lang),
  usageResumesProvider.overrideWithValue((onResume) {
    onResumes(onResume);
    return () => onResumes(null);
  }),
];
