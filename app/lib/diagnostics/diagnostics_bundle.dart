// A manually exported ZIP containing client, device and remote connection
// diagnostics. Every string is redacted before it enters the archive.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../performance/performance_state.dart';
import '../state/app_info.dart';
import '../state/connection_state.dart';
import '../state/settings_state.dart';
import '../state/voice_settings.dart';
import 'diagnostics_channel.dart';
import 'app_error_log.dart';
import 'redact.dart';
import 'zip_writer.dart';

/// Everything a bundle is made of, read from the app and Android.
class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.at,
    required this.settings,
    this.native = const NativeDiagnostics(),
    this.connection = const {},
    this.performance = const {},
    this.voiceMode = VoiceMode.auto,
    this.appErrors = const [],
  });

  final DateTime at;
  final AppSettings settings;
  final NativeDiagnostics native;

  /// Last observed remote connection state; may be stale. `not_observed`
  /// means no active observation is retained. Collection never connects.
  final Map<String, Object?> connection;
  final Map<String, Object?> performance;
  final VoiceMode voiceMode;
  final List<AppErrorRecord> appErrors;
}

abstract final class DiagnosticsBundle {
  static const mime = 'application/zip';

  /// ASCII name, sortable to the second.
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'dsh-go-diagnostics-${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}.zip';
  }

  static Map<String, Object?> summary(DiagnosticsSnapshot s) => {
    'generatedAt': s.at.toUtc().toIso8601String(),
    'timeZoneOffsetMinutes': s.at.timeZoneOffset.inMinutes,
    'app': {'version': AppInfo.version, ...s.native.app},
    'device': s.native.device,
    'connection': s.connection,
    'performance': s.performance,
    'voice': {...voiceDiagnosticsFacts(s.native.voice), 'mode': s.voiceMode.name},
  };

  static Map<String, Object?> settingsSummary(AppSettings s) => {
    'themeMode': s.themeMode.name,
    'chatTextScale': s.chatTextScale,
    'webPhoneLayout': s.webPhoneLayout,
    'foldCompletedTurns': s.foldCompletedTurns,
    'visualReplies': s.visualReplies,
  };

  /// The archive's files, every string redacted.
  static List<ZipEntry> entries(DiagnosticsSnapshot s) {
    const json = JsonEncoder.withIndent('  ');
    ZipEntry jsonFile(String name, Object? value) =>
        ZipEntry(name, utf8.encode('${json.convert(redactJson(value))}\n'));
    return [
      jsonFile('summary.json', summary(s)),
      jsonFile('settings.json', settingsSummary(s.settings)),
      if (s.appErrors.isNotEmpty) jsonFile('app-errors.json', s.appErrors.map((error) => error.toJson()).toList()),
    ];
  }

  static Uint8List build(DiagnosticsSnapshot s) => buildZip(entries(s), modified: s.at);
}

/// Reads only client state and Android facts. Missing sources are left out;
/// collection neither connects to a host nor sends any diagnostic data.
Future<DiagnosticsSnapshot> collectDiagnostics(Ref ref, DateTime at) async {
  final settings = ref.read(settingsProvider);
  final channel = ref.read(diagnosticsChannelProvider);
  const wait = Duration(seconds: 5);

  Future<T> attempt<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read().timeout(wait);
    } catch (_) {
      return fallback;
    }
  }

  return DiagnosticsSnapshot(
    at: at,
    settings: settings,
    native: await attempt(channel.info, const NativeDiagnostics()),
    connection: ref.read(connectionDiagnosticsProvider).snapshot,
    performance: performanceDiagnostics(ref),
    voiceMode: await attempt(() => ref.read(voiceSettingsProvider.notifier).ready(), VoiceMode.auto),
    appErrors: appErrorLog.snapshot(),
  );
}
