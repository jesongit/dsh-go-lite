// Android app/device diagnostics (`diagnostics/DiagnosticsPlugin.kt`).

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A second content boundary for the native voice observation. Unexpected
/// transcript/audio fields never enter an export, even from an older plugin.
Map<String, Object?> voiceDiagnosticsFacts(Object? raw) {
  if (raw is! Map) return const {};
  Map<String, Object?> fields(Map row) {
    const numbers = {'sdk', 'serviceVersion', 'serviceUpdatedAt', 'at', 'code'};
    const booleans = {
      'recognizerAvailable',
      'onDeviceFactoryApiAvailable',
      'onDeviceAvailable',
      'onDeviceFactoryProbed',
      'systemUnreliable',
    };
    const strings = {'defaultService', 'servicePackage', 'environmentId', 'name', 'stage', 'exceptionType'};
    return {
      for (final key in numbers)
        if (row[key] is num) key: row[key],
      for (final key in booleans)
        if (row[key] is bool) key: row[key],
      for (final key in strings)
        if (row[key] case final String value) key: value.length > 256 ? value.substring(0, 256) : value,
    };
  }

  final failures = raw['recentFailures'];
  final services = raw['visibleServices'];
  return {
    ...fields(raw),
    if (failures is List)
      'recentFailures': failures.whereType<Map>().toList().reversed.take(20).toList().reversed.map(fields).toList(),
    if (services is List)
      'visibleServices': services
          .whereType<String>()
          .take(16)
          .map((s) => s.length > 256 ? s.substring(0, 256) : s)
          .toList(),
  };
}

/// App and device facts only Android knows.
class NativeDiagnostics {
  const NativeDiagnostics({this.app = const {}, this.device = const {}, this.voice = const {}});

  factory NativeDiagnostics.fromMap(Map<Object?, Object?> map) {
    Map<String, Object?> section(Object? raw) =>
        raw is Map ? {for (final e in raw.entries) '${e.key}': e.value} : const {};
    return NativeDiagnostics(
      app: section(map['app']),
      device: section(map['device']),
      voice: voiceDiagnosticsFacts(map['voice']),
    );
  }

  /// `versionName`, `versionCode`, `abi`.
  final Map<String, Object?> app;

  /// `manufacturer`, `brand`, `model`, `android`, `sdkInt`, `abis`,
  /// `memoryMb`, `freeStorageMb`, and `display`.
  final Map<String, Object?> device;

  /// Content-free recognition service facts and at most 20 failure observations.
  final Map<String, Object?> voice;
}

/// MethodChannel `dsh/diagnostics`. Without the native side it answers empty.
class DiagnosticsChannel {
  const DiagnosticsChannel([this.channel = const MethodChannel('dsh/diagnostics')]);
  final MethodChannel channel;

  Future<NativeDiagnostics> info() async {
    try {
      final map = await channel.invokeMapMethod<Object?, Object?>('info');
      return map == null ? const NativeDiagnostics() : NativeDiagnostics.fromMap(map);
    } on MissingPluginException {
      return const NativeDiagnostics();
    }
  }
}

final diagnosticsChannelProvider = Provider<DiagnosticsChannel>((ref) => const DiagnosticsChannel());
