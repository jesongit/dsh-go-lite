import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A repair prompt waiting for the chat composer (「帮我修复」).
///
/// Client entry points call [RepairDraftController.request]; the chat screen listens, opens a new session, puts
/// the text in the composer **without sending it** (it costs tokens; the user decides)
/// and calls [take].
class RepairDraftController extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String text) => state = text;

  /// Returns the pending prompt once and clears it.
  String? take() {
    final text = state;
    state = null;
    return text;
  }
}

final repairDraftProvider = NotifierProvider<RepairDraftController, String?>(RepairDraftController.new);
