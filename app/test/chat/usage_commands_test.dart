// Slash-command catalog parsing and filtering, session usage from captured
// `session/control` frames, and the DeepSeek balance state.

import 'dart:convert';
import 'dart:io';

import 'package:dsh_app/state/commands_state.dart';
import 'package:dsh_app/state/usage_state.dart';
import 'package:dsh_app/ui/chat/slash_palette.dart';
import 'package:dsh_app/ui/chat/usage_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  group('slash commands', () {
    final all = mergeSlashCommands(testHostCommands);

    test('catalog: Chinese faces by definitionId, Web-only /export hidden', () {
      expect(testHostCommands.map((c) => c.name), ['goal', 'plan', 'feedback', 'compact', 'permission']);
      final compact = testHostCommands.firstWhere((c) => c.name == 'compact');
      expect(compact.label, '压缩');
      expect(compact.takesInput, isFalse);
      final permission = testHostCommands.firstWhere((c) => c.name == 'permission');
      expect(permission.hint, '<预设名>');
      expect(permission.takesInput, isTrue);
    });

    test('a same-name plugin override keeps its own copy', () {
      final parsed = parseCommandList([
        {'definitionId': 'my-plugin#compact', 'name': 'compact', 'description': 'Mine'},
        {
          'name': 'deploy',
          'description': 'Ship it',
          'input': {'hint': '<env>'},
        },
        {'description': 'no name'},
      ]);
      expect(parsed.map((c) => (c.name, c.label, c.description, c.hint)), [
        ('compact', 'compact', 'Mine', null),
        ('deploy', 'deploy', 'Ship it', '<env>'),
      ]);
    });

    test('palette order: app commands, first-party, then the rest', () {
      final withPlugin = mergeSlashCommands([
        ...parseCommandList([
          {'name': 'deploy', 'description': 'Ship it'},
        ]),
        ...testHostCommands,
      ]);
      expect(withPlugin.map((c) => c.name), [
        'new',
        'model',
        'compact',
        'permission',
        'plan',
        'goal',
        'feedback',
        'export',
        'features',
        'deploy',
      ]);
    });

    test('filter: name prefix, title, substring, subsequence', () {
      List<String> names(String q) => filterSlashCommands(all, q).map((c) => c.name).toList();
      expect(names(''), hasLength(all.length));
      expect(names('p'), ['permission', 'plan', 'compact', 'export']);
      expect(names('压'), ['compact']);
      expect(names('cpt'), ['compact']);
      expect(names('MOD'), ['model']);
      expect(names('zzz'), isEmpty);
    });

    test('parse and resolve a command line', () {
      expect(parseSlashInput('hello /compact'), isNull);
      final partial = parseSlashInput('/per')!;
      expect((partial.token, partial.hasArgs), ('per', false));
      final full = parseSlashInput('/permission read-only')!;
      expect((full.token, full.rest), ('permission', ' read-only'));
      final indented = parseSlashInput(' \t/permission read-only')!;
      expect((indented.token, indented.rest), ('permission', ' read-only'));
      expect(parseSlashInput(' \thello /permission'), isNull);
      expect(resolveSlashCommand(all, '压缩')?.name, 'compact');
      expect(resolveSlashCommand(all, 'perm'), isNull);
    });

    test('palette content: matches while typing, a hint once input starts', () {
      expect(PaletteContent.of(all, 'hi'), isNull);
      expect(PaletteContent.of(all, '/'), isA<PaletteMatches>());
      final hint = PaletteContent.of(all, '/permission ');
      expect(hint, isA<PaletteHint>());
      expect((hint! as PaletteHint).command.name, 'permission');
      expect(PaletteContent.of(all, '/compact now'), isNull);
      expect(PaletteContent.of(all, '/sdcard/a.txt 看看'), isNull);
    });

    test('palette filters the first token only up to the caret', () {
      final inserted = PaletteContent.of(all, '/已有文字', caret: 1) as PaletteMatches;
      expect(inserted.commands, all);
      expect(inserted.typed, isFalse);
      expect(PaletteContent.of(all, ' \t/已有文字', caret: 3), isA<PaletteMatches>());
      final partial = PaletteContent.of(all, '/permission read-only', caret: 4) as PaletteMatches;
      expect(partial.commands.first.name, 'permission');
      expect(PaletteContent.of(all, 'hello /', caret: 7), isNull);
      expect(PaletteContent.of(all, '/', caret: 0), isNull);
      expect(PaletteContent.of(all, '/', caret: -1), isNull);
      expect(PaletteContent.of(all, '/', caret: 2), isNull);
    });
  });

  group('session usage', () {
    test('folds captured session/control frames', () {
      final lines = File('../packages/dsh_client/test/fixtures/control_reply_ok.jsonl')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty);
      var values = <String, Object?>{};
      String? session;
      for (final line in lines) {
        final frame = jsonDecode(line) as Map<String, Object?>;
        if (frame['type'] == 'baseline') {
          final projections = (frame['value']! as Map)['projections'] as Map<String, Object?>;
          session ??= projections.keys.first;
          values = {...((projections[session]! as Map)['values'] as Map<String, Object?>)};
        } else if (frame['sessionId'] == session) {
          values[frame['key']! as String] = frame['value'];
        }
      }
      final usage = SessionUsage.fromProjections(values);
      expect(usage.uncachedInput, 10129);
      expect(usage.output, 2);
      expect(usage.input, 10129);
      expect(usage.cacheHitRate, 0);
      expect(usage.contextWindow, 1000000);
      expect(usage.pressureTokens, 10129);
      expect(usage.contextFraction, closeTo(0.0101, 0.0001));
      expect(usage.systemTokens, 1467);
      expect(usage.toolsTokens, 5157);
      expect(usage.turns, 1);
      expect(formatPercent(usage.contextFraction!), '1%');
    });

    test('empty projections: no window, no hit rate', () {
      final usage = SessionUsage.fromProjections(const {});
      expect(usage.contextFraction, isNull);
      expect(usage.cacheHitRate, isNull);
      expect(usage.hasTokens, isFalse);
    });

    test('cache hit rate and cost need real numbers', () {
      const usage = SessionUsage(uncachedInput: 2000, cacheRead: 6000, output: 500);
      expect(usage.cacheHitRate, 0.75);
      expect(knownPricing, isEmpty, reason: 'no prices are made up');
      const pricing = TokenPricing(currency: 'CNY', inputPerMillion: 2, cacheHitPerMillion: 0.5, outputPerMillion: 8);
      expect(estimateCost(usage, pricing), closeTo(0.011, 1e-9));
    });

    test('token and percent formatting', () {
      // K/M in every language: no 万/亿, whatever the UI language is.
      expect(formatTokens(0), '0');
      expect(formatTokens(999), '999');
      expect(formatTokens(1000), '1K');
      expect(formatTokens(8421), '8.4K');
      expect(formatTokens(15000), '15K');
      expect(formatTokens(43000), '43K');
      expect(formatTokens(500000), '500K');
      expect(formatTokens(999999), '1M'); // never 1000K
      expect(formatTokens(1000000), '1M');
      expect(formatTokens(1048576), '1.05M');
      expect(formatTokens(1050000), '1.05M');
      expect(formatTokens(100000000), '100M');
      expect(formatTokens(150000000), '150M');
      expect(formatPercent(0.004), '<1%');
      expect(formatPercent(0), '0%');
      expect(formatPercent(0.876), '88%');
    });
  });
}
