import 'package:dsh_app/state/hosts_state.dart';

class FixedActiveHost extends ActiveHostController {
  FixedActiveHost(this.host);

  final HostRef host;

  @override
  HostRef build() => host;

  @override
  Future<void> get ready => Future.value();
}

class FixedHosts extends HostsController {
  @override
  HostsState build() => const HostsState(
    loaded: true,
    ssh: [
      SshHostConfig(
        id: 'lab',
        name: '实验室服务器',
        host: 'lab.example.com',
        port: 22,
        user: 'root',
        auth: SshAuthMethod.privateKey,
      ),
    ],
  );
}
