import 'package:dsh_client/dsh_client.dart';

import 'answer_native_request.dart';

/// Answers one approval only in the generation that presented it.
Future<bool> answerRequestApproval({
  required DshClient client,
  required MuxGeneration generation,
  required ApprovalRequest request,
  required ApprovalDecision decision,
  required bool Function() current,
}) async {
  if (decision != ApprovalDecision.allowOnce && decision != ApprovalDecision.reject) {
    return false;
  }
  return answerNativeRequest(
    client: client,
    generation: generation,
    eventId: request.eventId,
    outcome: {'kind': 'result', 'value': decision.wire},
    current: current,
  );
}
