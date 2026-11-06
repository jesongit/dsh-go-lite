import 'package:dsh_client/dsh_client.dart';

/// An immediately ready mux for remote client fixtures with controlled transport
/// opening and no real network handshake.
class ReadyMux extends DshMux {
  ReadyMux() : super(DshHttpCarrier(DshConnection(Uri.parse('http://127.0.0.1:9'))));

  @override
  Future<MuxGeneration> ready({Duration? timeout}) async => const MuxGeneration(1, 'fixture', '/tmp');
}
