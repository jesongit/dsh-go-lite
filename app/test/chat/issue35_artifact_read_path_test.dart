import 'dart:io';

import 'package:dsh_app/state/artifact_files.dart';
import 'package:dsh_app/state/artifacts.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/state/connection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a localhost file link resolves against the remote Host filesystem', () async {
    final transcript = ChatTranscript();
    var seq = 0;
    void event(String type, Map<String, Object?> data) {
      transcript.apply(
        parseFollowFrame('s1', {
          'type': 'event',
          'event': {'type': type, 'seq': seq++, 'time': 1792900000000, 'data': data},
        }),
      );
    }

    event('turn/start', {'turn': 1});
    event('tool/call', {
      'turn': 1,
      'step': 1,
      'callId': 'read',
      'name': 'bash',
      'arguments': '{"command":"ls /root/report.docx"}',
    });
    event('tool/result', {
      'turn': 1,
      'step': 1,
      'message': {
        'id': 'result',
        'role': 'tool',
        'toolCallId': 'read',
        'isError': false,
        'content': [
          {'type': 'text', 'text': '/root/report.docx'},
        ],
      },
    });
    event('assistant/message', {
      'turn': 1,
      'step': 2,
      'message': {
        'id': 'answer',
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': '[document](file://localhost/root/report.docx)'},
        ],
      },
    });
    event('turn/end', {
      'turn': 1,
      'reason': {'kind': 'completed'},
    });
    final artifact = deriveArtifacts(
      events: transcript.events,
      turns: transcript.turns,
      cwd: '/root/workspace',
    ).single.files.single;
    expect(artifact.origin, ArtifactOrigin.linked);

    final directory = Directory.systemTemp.createTempSync('artifact-path-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final carrier = _RemoteFile();
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    final files = ArtifactFiles(
      connection: HostConnection(client: client, label: 'Host', hostId: 'host'),
      channel: const FilesChannel(),
      cacheRoot: () async => directory,
    );
    File? materialized;
    Object? failure;
    try {
      materialized = await files.materialize('s1', artifact);
    } catch (error) {
      failure = error;
    }
    expect(failure, isNull);
    expect(carrier.paths, isNotEmpty);
    expect(carrier.paths, everyElement('/root/report.docx'));
    expect(materialized!.readAsStringSync(), 'path fixture, no converter involved');
  });
}

class _RemoteFile extends DshCarrier {
  final paths = <String>[];
  @override
  String get kind => 'memory';
  @override
  DshTracer? get tracer => null;
  @override
  Future<RpcResult> call(String endpoint, Map<String, Object?> args, {Duration? timeout}) async {
    final path = args['path'] as String;
    paths.add(path);
    final content = 'path fixture, no converter involved'.codeUnits;
    final stat = {'absolutePath': path, 'version': 'v1', 'bytes': content.length};
    return switch (endpoint) {
      'workspaceFiles/stat' => RpcOk(stat),
      'workspaceFiles/readBytes' => RpcOk({...stat, 'offset': 0, 'data': content, 'eof': true}),
      _ => const RpcError(DshRemoteException('gateway/not-found', 'unused')),
    };
  }

  @override
  Future<DshMuxLink> openLink(MuxOptions options) => throw UnsupportedError('unused');
  @override
  Future<void> close() async {}
}
