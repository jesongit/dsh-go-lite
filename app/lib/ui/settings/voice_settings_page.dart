import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/voice_settings.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'settings_widgets.dart';

String voiceModeLabel(L10n l10n, VoiceMode mode) => switch (mode) {
  VoiceMode.auto => l10n.voiceModeAuto,
  VoiceMode.system => l10n.voiceModeSystem,
  VoiceMode.engine => l10n.voiceModeEngine,
};

class VoiceSettingsTile extends ConsumerWidget {
  const VoiceSettingsTile({super.key, this.tint = 0});
  final int tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsTile(
    key: const ValueKey('settings-voice'),
    icon: AppIcons.voice,
    tint: tint,
    spot: SettingsIndex.entry(SettingsPageId.voice),
    value: Text(voiceModeLabel(context.l10n, ref.watch(voiceSettingsProvider))),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VoiceSettingsPage())),
  );
}

class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = ref.watch(voiceSettingsProvider);
    return AppPage.list(
      title: l10n.voiceSettingsTitle,
      children: [
        SettingsSection(
          title: l10n.voiceModeSection,
          children: [
            for (final mode in VoiceMode.values)
              Semantics(
                checked: selected == mode,
                inMutuallyExclusiveGroup: true,
                child: SettingsTile(
                  key: ValueKey('voice-mode-${mode.name}'),
                  title: voiceModeLabel(l10n, mode),
                  subtitle: switch (mode) {
                    VoiceMode.auto => l10n.voiceModeAutoHint,
                    VoiceMode.system => l10n.voiceModeSystemHint,
                    VoiceMode.engine => l10n.voiceModeEngineHint,
                  },
                  trailing: SizedBox.square(
                    dimension: 32,
                    child: Icon(selected == mode ? AppIcons.radioOn : AppIcons.radioOff, size: 24),
                  ),
                  onTap: () => unawaited(ref.read(voiceSettingsProvider.notifier).setMode(mode)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
