// Idea after PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../diagnostics/redact.dart';
import '../../state/app_info.dart';
import '../../state/connection_state.dart';
import '../../state/settings_state.dart';
import '../common/brief_notice.dart';
import '../engine/diagnostics_export_card.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'settings_widgets.dart';

/// Client connection diagnostics, with manual copying and bundle export.
class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  static Map<String, Object?> report({required AppSettings settings, required String connection}) => {
    'app': AppInfo.version,
    'connection': connection,
    'settings': {'themeMode': settings.themeMode.name},
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final conn = ref.watch(activeConnectionProvider);
    final connection = switch (conn) {
      AsyncData(:final value) => value == null ? l10n.commonNotConnected : l10n.pluginsConnectedHost(value.label),
      AsyncError() => l10n.commonConnectionFailed,
      _ => l10n.pluginsConnecting,
    };
    Future<void> copyReport() async {
      final json = const JsonEncoder.withIndent('  ')
          .convert(redactJson(report(settings: settings, connection: connection)));
      await Clipboard.setData(ClipboardData(text: json));
      if (context.mounted) showBriefNotice(context, l10n.pluginsDiagnosticsCopied);
    }

    return AppPage.list(
      title: l10n.pluginsDiagnostics,
      children: [
        SettingsSection(
          children: [
            InfoRow(label: l10n.commonVersion, value: AppInfo.version),
            InfoRow(label: l10n.commonRemoteHost, value: connection),
            SettingsTile(icon: AppIcons.copy, title: l10n.pluginsCopyDiagnostics, onTap: copyReport),
          ],
        ),
        const DiagnosticsExportCard(),
      ],
    );
  }
}
