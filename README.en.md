# dsh-go-lite

[简体中文](README.md) · English

[jesongit/dsh-go-lite](https://github.com/jesongit/dsh-go-lite) is an independently maintained **remote-only Android client source snapshot** for connecting to DeepSeek Harness on a computer or server through SSH or DSH Remote. This public repository provides source code. It currently has no Releases of its own and no committed APKs.

The code comes from [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go), by [ccch1mneyyy / DSH-TUI](https://github.com/ccch1mneyyy). This is not an official upstream release or an official DeepSeek app; upstream binaries do not represent this snapshot.

`dsh-go-lite` is the repository name. The standard Android app is still named **DSH Go**; the parallel validation build displays **DSH Go Remote Test / DSH Go 远程测试**. The app name, icons and artwork have not been fully replaced. Brand and artwork remain subject to [ASSETS.md](ASSETS.md).

## Features and scope

The native Flutter UI and pure Dart client handle connections and presentation. The DSH engine, model requests, commands, workspaces and plugin logic run on the remote host you explicitly select.

- SSH or DSH Remote host management, connections and switching.
- Remote chat, model selection, workspaces, tool approvals and questions, steering and message queues.
- Existing plugin lists, toggles, tool cards and panels, subject to transport and host capabilities.
- Image and file attachments, remote file previews, caching, opening, saving and sharing, plus conversation sharing and replay.
- Client notifications, pets and overlays, themes and icons, Chinese and English UI, system speech and existing remote transcription.

Phone-local Linux/rootfs, PRoot, Direct, local runtime installation/update/start/reset/safe mode, local DeepSeek login and AI phone control have been removed. No remote phone-control protocol or feature-parity additions have been introduced.

Shared bridges, media plugins, host patches and the SDK remain in the source for remote hosts or developer tooling. They are not a phone DSH execution environment. See the [architecture](docs/architecture.md).

## Connecting and first use

You need **Android 8.0 / API 26+** and a computer or server running [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness). The current **targetSdk is 28**, targeting APK sideloading. The project supports `arm64` phone builds and `x64` local x86_64 emulator validation, with no 32-bit ARM flavor.

1. Build and install an APK using the steps below; this repository currently has no downloadable release package.
2. SSH: the host needs SSH and DSH, with `dsh web` as the default start command. Add the connection in the app and verify its host fingerprint.
3. DSH Remote: configure and sign in to the Remote plugin on the host, use the corresponding account on the phone, verify the identity fingerprint and explicitly select a host.
4. Configure models and credentials for the selected host, then start a conversation. See the [remote-host guide](docs/guide/en/03-engine-hosts.md).

**No selected host is a valid state (`HostRef.none`).** A first launch without hosts, an old removed local selection, deleting the current host or signing out of its Remote account never triggers a random fallback to another saved or online host. Auto-connect only tries a valid last remote target; with it disabled, connect manually. Connection failures do not redirect content to another host.

## Current remote limitations

| Capability | SSH | DSH Remote |
|---|---|---|
| Chat, workspaces and approvals | Existing remote APIs | APIs allowed by the transport and supported by the host |
| File uploads | Remote upload API | Negotiated `workspace.upload.v1`; older hosts accept images only |
| Plugin lists, marketplace and toggles | Existing remote endpoints | Currently allowed endpoints |
| Plugin installation/removal | Remote endpoints | Currently blocked; operate on the host |
| Native plugin UI, bridge configuration and assets | Compatible remote bridge required | HTTP bridge routes are unreachable |
| Embedded DSH Web and plugin WebViews | SSH tunnel | Currently unavailable |
| DS Bot and chat-log ZIP export | Relevant remote APIs required | Currently unavailable |
| Skill/personal-instruction file import/export | Some old paths need the phone runtime; not guaranteed | Not guaranteed |

DSH Remote's LAN/P2P, TURN or Relay path does not change its API allowlist. App conversation sharing and replay are separate from host log ZIP export. See the [user guide](docs/guide/README.md) for file limits and host capabilities.

## Existing installations and data

An update over the same package requires compatible original signing and a suitable increasing build number. Without the original signing key, use the independent parallel package below to keep the old app and its data. Do not resolve a signing mismatch by uninstalling the old app.

Upgrading does not automatically delete, reset, upload or migrate the old home, conversations, workspaces, plugins or credentials. An old local selection becomes invalid while private data remains. The new app cannot run that environment and has no automatic migration or cleanup wizard. Verify an external backup before manually migrating, then check paths, configuration and permissions on the target host. See [upgrading and legacy local data](docs/guide/en/04-legacy-data.md).

## Build from source

Run commands from the repository root. You need Git, Python 3, Flutter/Dart, **JDK 17** and Android SDK with the required build tools and licenses. Keep the complete project assets and dependency locks.

- The [CI configuration](.github/workflows/ci.yml) pins Flutter **3.47.7**; historical Windows verification used **3.47.9 / Dart 3.13.7**.
- The [app SDK constraint](app/pubspec.yaml) is Dart **`^3.13.5`**. Use a Flutter toolchain satisfying that constraint.
- Put Flutter and Java on `PATH` and set `JAVA_HOME` and `ANDROID_HOME` (`ANDROID_SDK_ROOT` if needed). No phone Linux/rootfs build is required.

```text
git clone https://github.com/jesongit/dsh-go-lite.git
cd dsh-go-lite
```

The public source can be cloned directly; pushing changes requires repository write access. Keep passwords, tokens and signing keys out of clone URLs, commands and the repository.

Windows / PowerShell:

```powershell
python tooling/build_apk.py -f arm64 --keep-daemon
```

Linux x86_64 / Bash with an existing toolchain:

```bash
bash tooling/build-apk.sh -f arm64 --keep-daemon
```

On Linux, optionally use [setup-toolchain.sh](tooling/setup-toolchain.sh) and source its generated `tooling/env.sh`. That installer targets Linux, not native Windows. For an x86_64 emulator, replace `-f arm64` with `-f x64` in the build command.

The standard arm64 output is `app/build/app/outputs/flutter-apk/app-arm64-release.apk`; the x64 equivalent is `app-x64-release.apk`. The scripts generate a build number, dependency resolution may need network access, and `--keep-daemon` preserves Gradle daemons.

Without `app/android/key.properties`, release builds retain the **debug signing fallback**. Updating an existing installation with the same package still requires its original signing key (or a compatible valid signing lineage). Local debug signing is not upstream release signing. Do not commit keys or passwords.

## Install the parallel remote test app

The [Gradle configuration](app/android/app/build.gradle.kts) enables the independent applicationId `io.github.ccch1mneyyy.dsh_app.remote_test` when explicitly passed `dshParallelInstall=true` for that build. The standard package remains `io.github.ccch1mneyyy.dsh_app`. The source snapshot includes the `app/android/app/src/parallel/` overlay, isolating provider authorities, shortcut targets and app labels while retaining the original namespace and signing policy.

**Standard and parallel builds both write to the same `app-arm64-release.apk` path. Copy each completed build to a distinct filename before starting another build.** This example saves an existing standard APK, then builds and saves the parallel APK. Choose other destination names if these files already contain something you need:

```powershell
Copy-Item app/build/app/outputs/flutter-apk/app-arm64-release.apk ./app-arm64-standard-release.apk
python tooling/build_apk.py -f arm64 --keep-daemon -- --android-project-arg=dshParallelInstall=true
Copy-Item app/build/app/outputs/flutter-apk/app-arm64-release.apk ./app-arm64-remote-test-release.apk
adb install ./app-arm64-remote-test-release.apk
```

For a parallel build alone, start at the `python` line. Use this verified explicit argument; the environment-variable form previously failed and is not a supported instruction here. Omit the argument for a standard build.

The parallel package preserves the old app and its data. Host configuration, private data and system permissions are independent and need fresh setup; old data is not automatically imported or uploaded. Both apps can handle `dshgo` links, so Android may ask which app to open. See the [parallel-install validation record](docs/maintenance/parallel-install-validation.md).

## Recorded validation and remaining work

The following is **historical local evidence** retained with the snapshot. It does not establish green CI for this repository or current device validation. This README update did not rerun builds or tests.

| Check | Recorded result |
|---|---|
| App static analysis | Zero issues from `flutter analyze --no-pub` |
| Representative remote/host/state behavior tests | 1,159 passed, 16 skipped |
| Sharing/UI configuration/artifact-file tests | 264 passed, 2 skipped |
| Bot and Agent batch | 503 passed, 15 skipped, 0 failed |
| Local APK inspection | Standard arm64/x64 and parallel arm64 were built; package identity, ABI, SDK, signing and absence of rootfs payloads were checked |

Reruns and differing scopes overlap, so these batches are not added into a full-suite pass count. Windows golden images, file/symlink behavior, shared host Node tests, SDK and shared Dart packages still have documented baseline failures. The complete Flutter baseline did not finish, and no all-green CI result has been verified.

Device validation remains incomplete for real SSH/Remote login and reconnection, Android background notifications and pets, file interactions, updates with the original signing key, and parallel-package installation/launch. Details, skip reasons and historical environments are in the [remote-only validation record](docs/maintenance/remote-only-validation.md) and [parallel validation record](docs/maintenance/parallel-install-validation.md).

## Documentation and data handling

- [User guide](docs/guide/README.md): connections, chat, files, plugins, notifications, pets and appearance.
- [Architecture](docs/architecture.md) and [contribution/validation contract](CONTRIBUTING.en.md): development scope and checks. External PRs are currently not accepted.
- [Plugin development](docs/plugins/en/README.md) and [SDK](sdk/plugin-kit/README.en.md): host plugins and client UI integration.

Messages, attachments and submitted configuration go to the explicitly selected host, whose providers handle model requests. Anonymous usage statistics are on by default and can be disabled during onboarding or in settings; see [troubleshooting](docs/guide/en/11-faq.md) for scope. Client notifications, files, speech and overlays request Android permissions as needed. Review content and credentials before sharing or sending diagnostics.

Read other bundled references to upstream releases, services, historical paths and local execution in the context of this page. They do not mean this repository supplies those packages or services.

## License, attribution and assets

Code is licensed under [AGPL-3.0](LICENSE); `sdk/` and `examples/` remain **MIT**. Third-party components retain their own terms. Modifications and redistribution must retain applicable copyright, license, source and modification notices and satisfy the corresponding source obligations.

- Upstream: [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go), by **ccch1mneyyy / DSH-TUI**.
- Remote engine: [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).
- Mascots: [DSH-TUI](https://github.com/ccch1mneyyy/dsh-TUI). Remote connections draw on [DSHarness Remote](https://github.com/liguobao/ds-harness-remote), by liguobao / Li Guobao.
- Full third-party sources and terms: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**DSH Go brand graphics, Deepy, Whale girl and related showcase artwork are outside the AGPL code license** and belong to their respective owners. Under [ASSETS.md](ASSETS.md), they may be used to build, test and run this repository; redistribution as a modified or derivative product requires your own name and assets. The repository name and test labels do not mean that work is complete or grant additional asset rights.

This snapshot is maintained independently of the upstream author and DeepSeek and does not represent an official release or endorsement from either.
