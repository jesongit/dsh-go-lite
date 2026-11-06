import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme.dart';

enum NoteTone { info, warn, danger }

/// A tinted callout: why something can't work, or what to know first.
class PermissionNote extends StatelessWidget {
  const PermissionNote({
    super.key,
    required this.text,
    this.title,
    this.tone = NoteTone.info,
    this.icon,
    this.action,
    this.margin = const EdgeInsets.fromLTRB(16, 6, 16, 6),
  });

  final String? title;
  final String text;
  final NoteTone tone;
  final IconData? icon;

  /// Optional button under the text.
  final Widget? action;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final (bg, fg, glyph) = switch (tone) {
      NoteTone.info => (colors.infoContainer, colors.onInfoContainer, AppIcons.info),
      NoteTone.warn => (colors.warningContainer, colors.onWarningContainer, AppIcons.warning),
      NoteTone.danger => (colors.dangerContainer, colors.onDangerContainer, AppIcons.blocked),
    };
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: bg,
            shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon ?? glyph, size: 20, color: fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title case final title?) ...[
                        Text(title, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
                        const SizedBox(height: 2),
                      ],
                      Text(text, style: theme.textTheme.bodySmall?.copyWith(color: fg, height: 1.5)),
                      if (action case final action?) ...[const SizedBox(height: 6), action],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Numbered steps inside a card.
class NumberedSteps extends StatelessWidget {
  const NumberedSteps(this.steps, {super.key});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(color: scheme.primaryContainer, shape: const CircleBorder()),
                  child: SizedBox.square(
                    dimension: 22,
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: AppType.tabular(theme.textTheme.labelMedium!.copyWith(color: scheme.onPrimaryContainer)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
