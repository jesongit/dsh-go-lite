import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../features/agent_presets_page.dart';
import '../shell/page_frame.dart';
import 'settings_widgets.dart';

class PersonalizationPage extends ConsumerWidget {
  const PersonalizationPage({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AppPage.list(
      title: l10n.hubPersonalization,
      children: [
        SettingsSection(
          title: l10n.hubPersonalizationWorkStyle,
          children: [
            SettingsTile(
              spot: SettingsIndex.entry(SettingsPageId.agentPresets),
              onTap: () => _push(context, const AgentPresetsPage()),
            ),
          ],
        ),
      ],
    );
  }
}
