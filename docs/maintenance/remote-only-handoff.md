# 移除手机本地 DSH 运行能力：会话交接

记录日期：2026-11-06。工作目录：`D:\code\dsh-Go`。

> **历史交接记录**：下文保留原分析会话的状态。用户随后已明确授权上述范围并实施纯远程改造；当前实现、APK、基线对照、失败/跳过项和未运行的真机验证以 [实现与验证记录](remote-only-validation.md) 为准。本次没有提交或发布。

## 目标与授权状态

用户希望删除本项目中关于手机本地运行 DSH 的内容，将 App 收敛为远程 DSH 客户端。本会话先完成了可行性分析与开发环境核查；用户随后要求留下交接文档，准备新开会话实施。

**截至本次交接，没有实施业务代码删除或重构，没有运行项目依赖解析、分析、测试、APK 构建或真机验证。** 仅运行了开发工具版本与环境检查，并创建本文档。创建本文档前，`git status --short` 无输出。

以下功能范围是本会话提出的实施建议，尚未逐项得到用户确认。新会话如果收到明确采用此范围并开始实施的提示，可以直接按提示执行；本文本身不构成额外授权。不要根据本文擅自清除用户数据、上传凭据、提交、推送、创建 PR 或发布。

## 建议实施范围

- 删除手机本地执行 DSH 的能力，包括 Ubuntu/rootfs、Node 打包、PRoot 和 Direct 两条启动路径、安装升级、自启动、日志、安全模式及本地引擎设置入口。
- 保留 SSH 和 DSH Remote 两种远程连接及它们目前各自已有的能力。
- 保留远程聊天、会话、工作区、工具审批、客户端插件渲染、主题、图标、桌宠、通知、文件预览和分享等客户端能力。
- 同步移除仅服务本机引擎的 DeepSeek 账号登录入口，以及当前仅供本机引擎使用的 AI 手机操控功能。保留后者需要另做远程工具执行协议，不属于简单删除。
- 不在本次改造中补齐 SSH 与 DSH Remote 的功能差异，不顺带大改架构、升级依赖或提高 targetSdk。
- 旧本地环境默认保留，禁止升级时静默 reset 或删除。提供迁移说明，按授权和可用验证条件决定是否实现备份/手动清理入口。

## 可行性结论

可行。项目已经支持不安装本机环境、直接使用远程主机；远程连接有独立实现，再统一交给聊天和会话界面。主要工作是解除启动与共享状态中的本机假设、删除本地执行链、同步构建与文档，而非重写远程客户端。

关键证据：

- [connection_state.dart](../../app/lib/state/connection_state.dart#L182-L267)：SSH、Relay 连接独立建立。
- [settings_overview_remote_test.dart](../../app/test/settings/settings_overview_remote_test.dart#L59-L73)：已有无本机环境、使用远程主机的界面测试。
- [root_gate.dart](../../app/lib/ui/shell/root_gate.dart#L280-L367)：当前启动仍等待运行时状态，处理安装、技能安装和自动启动。
- [hosts_state.dart](../../app/lib/state/hosts_state.dart#L304-L361)：当前主机默认值、删除远程主机及退出远程账号后的回退目标仍是本机。

需要明确表示“未选择主机/未连接”，而不是保留虚假的本机主机，或者遇到无效配置便连接任意远程主机。覆盖首次安装、旧配置指向本机、删除最后一台主机、退出 Relay 账号、关闭启动自动连接、主机离线等情况。

## 当前远程功能边界

| 功能 | SSH | DSH Remote / Relay |
| --- | --- | --- |
| 聊天、会话与基础操作 | 已有 | 已有 |
| 插件市场、清单、开关 | 已有 | 已有，按现有接口能力 |
| 插件安装、卸载 | 已有 | 当前 carrier 白名单未放行 |
| 原生插件界面、配置及素材 | 远端安装 bridge 后有实现 | 当前受 HTTP carrier 限制 |
| 官方 DSH Web / 插件 WebView | 有 SSH 本地端口转发 | 当前不可用 |
| DS Bot | 已有 HTTP/SSE | 客户端有 RPC 适配，但当前白名单未放行相应端点 |
| 配置与插件分享 | 有远程路径 | 按远端接口能力 |
| 技能及用户指令文件的部分导入导出 | 当前仍有本机文件系统专属实现 | 同样不能假定可用 |
| 操控这台手机 | 没有已实现的远程替代 | 没有已实现的远程替代 |

具体实现应再次按源码确认，不能仅依据旧文档或注释判断：

- [dsh_web_launcher.dart](../../app/lib/ui/web/dsh_web_launcher.dart#L43-L60)：SSH Web 与 Relay 的差异。SSH 的 loopback/local forward 属于远程连接基础，必须保留。
- [tunnel_carrier.dart](../../packages/dsh_remote/lib/src/carrier/tunnel_carrier.dart#L19-L123)：Remote 固定端点白名单。
- [dsbot_api.dart](../../packages/dsh_client/lib/src/dsbot_api.dart#L1389-L1397)：已有 DS Bot RPC 适配；有适配不等于实际传输已放行。
- [dsh_go_api.dart](../../packages/dsh_client/lib/src/dsh_go_api.dart#L671-L673)：原生插件桥的 HTTP carrier 限制。
- [share_import.dart](../../app/lib/share_code/share_import.dart#L441-L453)、[profile_export.dart](../../app/lib/share_code/profile_export.dart#L221-L238)：技能/指令文件的本机路径。

## 不能直接整目录删除的内容

### 共享客户端和插件

- [dsh_client](../../packages/dsh_client)、[dsh_remote](../../packages/dsh_remote) 是远程通信基础。
- [runtime](../../runtime) 目录不全是手机运行时，不能整体删除。
- [dsh-go-bridge](../../runtime/bridge/dsh-go-bridge) 可供远程主机安装，并承担插件协议和部分路由鉴权。[cordis.patch.yml](../../runtime/bridge/dsh-go-bridge/cordis.patch.yml#L1) 明确说明远程用途。
- [sync-bridge.mjs](../../sdk/plugin-kit/scripts/sync-bridge.mjs#L14-L29) 直接使用 bridge 源码同步 SDK 模块；移动源码时必须同步调整生成器和测试，不能手改生成物。
- [dsh-media](../../runtime/media/dsh-media) 是独立插件，应保留或迁出；参见 [PUBLISH.md](../../runtime/media/dsh-media/PUBLISH.md)。
- [CI](../../.github/workflows/ci.yml#L194-L229) 的共享宿主/桥测试依赖运行时版本、锁和准备脚本。先拆出这些用途，再删除只为 rootfs 打包服务的部分。不能整体删除运行时测试和补丁。

### Android 共享能力

- [RuntimeBridge](../../app/lib/runtime/runtime_bridge.dart#L615-L688) 同时承载存储、后台设置、省电豁免和计费网络等接口，应先拆出仍需要的通用能力。
- [MainActivity](../../app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/MainActivity.kt) 分别注册运行时、文件、媒体、分享等插件。Android 的 `FlutterEngine` 是界面执行器，不能当成本地 DSH 引擎删除。
- 本地引擎服务可以删除，但远程桌宠有独立的 [PetOverlayService](../../app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/pet/PetOverlayService.kt)，不能随之删除全部前台服务、通知、悬浮窗权限。
- [FilesPlugin](../../app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/files/FilesPlugin.kt) 既处理 guest 文件，也处理远程缓存文件的打开、保存和 PDF；应删除本机分支，保留客户端用途。Android 8/9 下载保存仍可能使用旧存储权限。
- [FileProvider 配置](../../app/android/app/src/main/res/xml/dsh_file_paths.xml) 保留缓存及更新文件用途，按需移除 rootfs 暴露路径。

## 必须处理的功能耦合

- [phone_state.dart](../../app/lib/state/phone_state.dart#L350-L369) 明确阻止远程主机使用手机操控。现有工具注入在 [PhoneGuest.kt](../../app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneGuest.kt)。保留手机操控需要新增远端 Agent 到手机的执行通道、身份与权限、确认、取消和断线生命周期。
- [account_state.dart](../../app/lib/state/account_state.dart#L32-L42) 的 DeepSeek 账号登录只用本机连接和 loopback OAuth 回调。它与 DSH Remote 登录不同，不能把两者一起删。
- [ui_config_state.dart](../../app/lib/ui_config/ui_config_state.dart#L61-L80) 已有本机与远程配置来源，保留远程与 App 自身设置回退。
- [artifact_files.dart](../../app/lib/state/artifact_files.dart#L124-L180) 已有远程文件下载/缓存逻辑，保留；清理本机 guest 文件分支。
- [provider_keys.dart](../../app/lib/state/provider_keys.dart) 的本机 Key 恢复机制不能改为自动向远程主机推送旧凭据。
- 继续检查通知、快捷方式、分享导入目标、最近会话、离线缓存身份、启动动画及诊断中 `HostRef.local`、`localRuntimeProvider`、`localConnectionProvider`、`GuestFs` 的引用。

## 构建与升级

- [build.gradle.kts](../../app/android/app/build.gradle.kts#L68-L96) 接入每 ABI 的运行时 assets/jniLibs、PRoot 打包规则和压缩格式；移除本地载荷相关配置与 xz 解包依赖。
- 先保留 arm64/x64 flavor、应用包名、签名、递增 versionCode、正式 APK 文件名及更新清单契约，避免把发布格式迁移混进来。
- Flutter/WebRTC 仍含原生库，移除 rootfs 不意味着 APK 不再区分 ABI。
- [tooling](../../tooling) 中构建号、APK、增量更新、开发工具链仍有客户端用途，不能整体删除。
- targetSdk 28 的旧理由是运行私有目录中的可执行文件。删除本地后可以另行评估提高版本，但涉及权限、文件、后台与安装行为，本次不顺带处理。
- [RuntimeInstaller.kt](../../app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/RuntimeInstaller.kt) 除 `filesDir/runtime/rootfs` 外，还管理 staging、home.carry、keep.trash、runtime.reset、runtime-keep 等状态。备份或清理应考虑中断安装/重置留下的数据。
- 旧 `/root` 中含会话、工作区、插件和凭据。保留本地文件不等于完成远程迁移；工作目录及绝对路径可能需要修复。
- 禁止自动上传旧主目录或凭据，禁止通过清空整个 App 数据目录来完成清理。覆盖安装需要相同签名；debug 签名包不能直接覆盖不同签名的官方包。

## 当前开发环境（2026-11-06 实测）

Windows，工具多由 Scoop 安装：

| 工具 | 状态 |
| --- | --- |
| Flutter | `D:\Scoop\apps\flutter\current\bin\flutter.bat`，3.47.9 stable |
| Dart | Flutter 自带 3.13.7，满足 App 的 `^3.13.5` |
| Java | 默认 Temurin 21.0.12.1；另有 `D:\Scoop\apps\openjdk17\current`，实测 17.0.2 |
| Android SDK | `D:\Scoop\apps\android-clt\current`，Android 36、Build Tools 36.0.0 |
| Android NDK | 28.2.13676358，已核实版本文件 |
| Android CMake | 3.22.1，已实际运行版本命令 |
| Android SDK 许可 | 用户最新 doctor 显示全部接受 |
| Node.js | 24.14.0 |
| Python | 3.14.3 |
| Android 手机/模拟器 | 未检测到；desktop/Chrome/Edge 不算 Android 设备 |

注意事项：

- 文档采用 Flutter 3.47.7，当前安装 3.47.9 是同系列补丁版本，尚未通过项目基线验证；先实际解析与检查，不要未经验证宣称完全兼容，也不要先行大幅升级。
- 当前 DSH 进程可能未继承新 PATH。可以在单次 PowerShell 命令中设置 `$env:PATH = 'D:\Scoop\apps\flutter\current\bin;' + $env:PATH`，或使用完整路径。
- Flutter doctor 的 SDK 路径告警来自 Scoop `current` junction 指向 `3.47.9`，已确认是同一安装，不必反复改 PATH。
- 两份 ADB：SDK 内置与独立 Scoop adb。`D:\Scoop\shims\adb.shim` 指向独立 adb。若真机连接冲突，使用 SDK 完整路径；不要未经必要性判断修改全局安装。
- Google Maven 的 doctor 连接检查超时；本会话早期 GitHub 检查也超时。后续是否阻塞 Gradle/pub 依赖下载尚未实测，不能仅以 doctor 超时认定构建必失败。
- Visual Studio 缺 Windows 桌面 C++ 组件，与本次 Android 构建无关。
- [setup-toolchain.sh](../../tooling/setup-toolchain.sh) 下载 Linux 工具，不能直接在 Windows 上照搬。可使用 Windows 原生 Flutter/Android 工具链；针对现有 Bash 脚本按需适配或采用等效命令，不需要为了纯客户端任务先构建 Linux 运行时。
- 仓库建议 JDK 17；若构建选择已有 JDK 17，优先为本次命令指定，不擅自全局覆盖其他项目 Java 配置。

## 建议执行顺序与验收

1. 先读 [AGENTS.md](../../AGENTS.md)、[CONTRIBUTING.md](../../CONTRIBUTING.md)、[architecture.md](../architecture.md)，检查工作区新变化。本文行号可能随实现变化。
2. 跑依赖解析、静态分析与必要测试建立基线，记录网络或已有失败。不要将已有失败归因于本次改动。
3. 先改主机模型和启动引导，让“无本机、无远程主机”成为正常可用的连接入口，再逐层退出本机调用。
4. 删除本地执行和专属 UI，拆出共享 Android 接口，保留远程协议与插件基础。
5. 同步 Gradle、CI、构建脚本、发布说明、文案和指南；按仓库生成流程运行生成器。
6. 测试首次使用、旧本机选择升级、无主机、删最后主机、Relay 登出、禁用自动连接、离线/重连、切换主机、通知/快捷方式返回正确会话，以及原生和 SSH 网页模式。
7. 检查插件、远程文件与分享等客户端能力，按真实远端支持判断能力，不能为了消除报错假装支持。
8. 构建 APK，确认不再打包或启动手机 Linux/DSH 运行时，保留必要 Flutter/WebRTC 库和发布契约。
9. 真机执行覆盖升级、启动、远程连接、后台与桌宠验证。没有设备/账号时明确写“未运行”及原因，不以桌面测试替代。
10. 总结改动、实际命令和结果、数据保留策略、仍需真机确认的部分。未经要求不 commit、push、建 PR、打 tag 或发布。

常用检查（按改动范围选择；以下为命令示意，应在对应目录运行）：

```text
app: flutter pub get; flutter analyze; flutter test
packages/dsh_client: dart pub get; dart analyze; dart test
packages/dsh_remote: dart pub get; dart analyze; dart test
sdk/plugin-kit: npm install; npm test
node --test runtime/tests/*.test.mjs
python app/tool/l10n_merge.py --check
python app/tool/guide_sync.py --check
```

Windows 下 Node 的测试 glob 和 Bash 构建入口可能需要等效参数展开；先读对应脚本，不盲目照抄。中英文 ARB 修改输入后运行生成器；指南修改后同步内置技能。README、CONTRIBUTING、SECURITY 和指南的修改按仓库要求同步中英文。本文是维护交接记录，不是替代用户指南。
