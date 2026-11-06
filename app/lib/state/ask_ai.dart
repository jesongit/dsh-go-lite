// 「问 AI」: a question about the app, put in a new conversation's composer
// (not sent) so the agent answers it from the bundled user guide
// (docs/guide, the dsh-go-guide skill). The UI side — closing the pages and
// handing the request to the chat — is ui/common/ask_ai.dart; the design is
// docs/design/risk-notices-and-ask-ai.md §4.
//
// How the guide reaches the agent depends on the host:
//
//   a remote host that    the question, plus the matching guide page from the
//   takes files (SSH)     app's assets as a Markdown attachment
//   one that doesn't      the question alone, and a line above the composer
//   (DSH Remote)          saying the answer may be off

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../ui_config/ui_skill.dart' show guideSkillName;
import 'attachments.dart';
import 'compose_inbox.dart';
import 'ui_mode_state.dart';

/// What a 「问 AI」 entry asks. Each has one question and the guide page that
/// answers it; entries exist only where the guide covers the topic.
enum AskAiTopic {
  /// 设置 › 关于 › 使用帮助.
  overview,

  /// Full-access permissions on the selected remote host.
  fullAccess,

  /// The approval card's 本对话都允许.
  allowForChat,

  /// 插件's page.
  plugins,

  /// 远程主机's page.
  remote;

  String get question => switch (this) {
    overview => appL10n.askAiQuestionOverview,
    fullAccess => appL10n.askAiQuestionFullAccess,
    allowForChat => appL10n.askAiQuestionAllowForChat,
    plugins => appL10n.askAiQuestionPlugins,
    remote => appL10n.askAiQuestionRemote,
  };

  /// The page of `docs/guide/<lang>/` that answers [question].
  String get guidePage => switch (this) {
    overview || fullAccess => '10-settings',
    allowForChat => '01-chat',
    plugins => '08-plugins',
    remote => '03-engine-hosts',
  };
}

/// How the guide gets to the host's agent.
enum GuideRoute {
  /// Files go through: the page rides along as an attachment.
  attachment,

  /// Neither: the question alone.
  none,
}

/// [GuideRoute] for the active host, according to its file capability.
GuideRoute guideRouteFor({required bool filesAllowed}) => filesAllowed ? GuideRoute.attachment : GuideRoute.none;

/// Reads a bundled asset as text (tests swap in a map).
typedef GuidePageReader = Future<String> Function(String asset);

final guidePageReaderProvider = Provider<GuidePageReader>((ref) => rootBundle.loadString);

/// The asset of a guide [page] (`03-engine-hosts`): flat in the skill's
/// asset folder, prefixed with the language (tool/guide_sync.py).
String guidePageAsset(String page, {required bool english}) =>
    'assets/skills/$guideSkillName/${english ? 'en' : 'zh'}-$page.md';

/// The attachment's name: `dsh-go-guide-engine-hosts.md`.
String guideAttachmentName(String page) => '$guideSkillName-${page.replaceFirst(RegExp(r'^\d+-'), '')}.md';

/// The guide page a question of the person's own (typed into settings
/// search) rides with: the settings page.
const freeQuestionGuidePage = '10-settings';

/// The composer fill for [topic] over [route]. A guide page that can't be read
/// falls back to the question alone, with the note.
Future<ComposeRequest> askAiRequest(
  AskAiTopic topic, {
  required GuideRoute route,
  required GuidePageReader read,
  bool? english,
}) => askAiQuestionRequest(topic.question, topic.guidePage, route: route, read: read, english: english);

/// [askAiRequest] for any [question], with [guidePage] the page that rides
/// along where the host takes files.
Future<ComposeRequest> askAiQuestionRequest(
  String question,
  String guidePage, {
  required GuideRoute route,
  required GuidePageReader read,
  bool? english,
}) async {
  final fallback = ComposeRequest(text: appL10n.askAiAboutApp(question), note: appL10n.askAiNoGuide);
  switch (route) {
    case GuideRoute.none:
      return fallback;
    case GuideRoute.attachment:
      final String page;
      try {
        page = await read(guidePageAsset(guidePage, english: english ?? AppLocale.isEnglish));
      } catch (_) {
        return fallback;
      }
      final file = DraftAttachment.sniff(guideAttachmentName(guidePage), Uint8List.fromList(utf8.encode(page)));
      return ComposeRequest(text: appL10n.askAiWithGuide(question), attachments: [file]);
  }
}

/// Whether 「问 AI」 entries show: not in 网页模式, where the home is the web
/// page and the native composer isn't there to take the question.
final askAiAvailableProvider = Provider<bool>((ref) => !ref.watch(uiModeProvider.select((s) => s.web)));
