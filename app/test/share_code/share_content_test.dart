import 'package:dsh_app/share_code/share_models.dart';
import 'package:dsh_app/ui/share_code/import_sheet.dart';
import 'package:dsh_app/ui/share_code/share_code_widgets.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/golden_harness.dart';
import 'support/fake_engine.dart';
import 'support/sheet_support.dart';

void main() {
  testWidgets('unsupported instructions and skills remain viewable without selection controls', (tester) async {
    usePhoneSurface(tester);
    const profile = ProfileShare(
      skills: [
        SharedSkill(name: 'quick', files: {'extra.txt': '另一份内容', 'SKILL.md': '技能全文'}),
      ],
      agentsMd: '偏好第一行\n偏好最后一行',
    );
    await tester.pumpWidget(
      goldenApp(
        brightness: Brightness.light,
        home: SheetHost(open: (c) => showShareImportSheet(c, profile)),
        overrides: shareOverrides(net: FakeShareNet(), targets: [remoteTarget(DshClient.withCarrier(FakeEngine()))]),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-import-integrity')), findsNothing);
    expect(find.byType(ShareCheck), findsNothing);
    expect(find.text('这台主机不支持这个操作'), findsNWidgets(2));
    final apply = tester.widget<FilledButton>(find.byKey(const ValueKey('share-import-primary')));
    expect(apply.onPressed, isNull);
    final view = find.byKey(const ValueKey('share-view-agents-md'));
    expect(tester.getSize(view), const Size(44, 44));
    await tester.tap(view);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is SelectableText && w.data == profile.agentsMd), findsOneWidget);
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-view-skill:quick')));
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(const ValueKey('share-file-SKILL.md')));
    final second = tester.getRect(find.byKey(const ValueKey('share-file-extra.txt')));
    expect(first.top, lessThan(second.top));
    await tester.tap(find.byKey(const ValueKey('share-file-SKILL.md')));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is SelectableText && w.data == '技能全文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
