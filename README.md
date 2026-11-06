# dsh-go-lite

简体中文 · [English](README.en.md)

[jesongit/dsh-go-lite](https://github.com/jesongit/dsh-go-lite) 是独立维护的**纯远程 Android 客户端源码快照**，用于通过 SSH 或 DSH Remote 连接电脑、服务器上的 DeepSeek Harness。本仓库公开提供源码，目前没有本仓库的 Releases，也未提交 APK。

代码源自 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)，原作者为 [ccch1mneyyy / DSH-TUI](https://github.com/ccch1mneyyy)。这不是上游官方发行版，也不是 DeepSeek 官方应用；上游下载的二进制文件不代表本快照。

`dsh-go-lite` 是仓库名称。当前普通 Android 应用仍名为 **DSH Go**，并行验证版显示 **DSH Go Remote Test / DSH Go 远程测试**；尚未完成应用名称、图标和素材的完整更换。品牌与美术素材另受 [ASSETS.md](ASSETS.md) 约束。

## 功能与范围

Flutter 原生界面与纯 Dart 客户端负责连接和显示；DSH 引擎、模型请求、命令、工作区和插件逻辑在明确选择的远程主机运行。

- SSH 或 DSH Remote 主机管理、连接与切换。
- 远程聊天、模型选择、工作区、工具审批与提问、插话与消息排队。
- 现有插件列表、开关、工具卡和面板；可用范围取决于传输和主机。
- 图片与文件附件、远程文件预览、缓存、打开、保存和分享，以及对话分享与回放。
- 客户端通知、桌宠与浮窗、主题和图标设置、中英文界面、系统语音及既有远程转写。

手机 Linux/rootfs、PRoot、Direct、本机运行环境的安装/更新/启动/重置/安全模式、本机 DeepSeek 登录和 AI 手机操控已移除。没有增加远程手机操控，也没有补齐两种连接方式间的功能差异。

共享的 bridge、媒体插件、宿主补丁和 SDK 仍在源码中供远程主机或开发工具使用，不是手机上的 DSH 执行环境。详见[架构](docs/architecture.md)。

## 连接与首次使用

需要 Android **8.0 / API 26+** 和一台运行 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的电脑或服务器。当前 `targetSdk` 为 **28**，以 APK 侧载为目标。支持 `arm64` 手机构建和 `x64` 本地 x86_64 模拟器验证，没有 32 位 ARM flavor。

1. 从下文构建并安装 APK；本仓库目前没有可下载的发行包。
2. SSH：主机需有 SSH 和 DSH，默认启动命令为 `dsh web`；在 App 添加连接并核对主机指纹。
3. DSH Remote：在主机配置 Remote 插件并登录，手机使用对应账号，核对身份指纹后明确选择主机。
4. 在所选主机配置模型和所需凭据，再开始对话。连接步骤见[远程主机指南](docs/guide/zh/03-engine-hosts.md)。

**未选择主机是正常状态（`HostRef.none`）**：首次没有主机、旧配置选中已移除的本机、删除当前主机或退出当前 Remote 账号后，都不会随机回退到其他已保存或在线的主机。开启自动连接时只尝试有效的上次远程目标；关闭后手动连接，连接失败也不会改发给其他主机。

## 当前远程限制

| 能力 | SSH | DSH Remote |
|---|---|---|
| 聊天、工作区、审批 | 远端现有 API | 传输放行且主机支持的 API |
| 文件上传 | 远端上传 API | 需协商 `workspace.upload.v1`；旧主机仅图片 |
| 插件列表、市场与开关 | 远端现有接口 | 当前放行接口 |
| 插件安装/卸载 | 远端接口 | 当前未放行，需在主机操作 |
| 原生插件界面、桥接配置与素材 | 需远端兼容 bridge | HTTP 桥接路由不可达 |
| 内嵌 DSH Web、插件 WebView | SSH 隧道 | 当前不可用 |
| DS Bot、对话日志 ZIP 导出 | 需远端相应 API | 当前不可用 |
| 技能/个人指令文件导入导出 | 部分旧路径依赖手机运行环境，不保证可用 | 不保证可用 |

DSH Remote 的 LAN/P2P、TURN 或 Relay 路径不改变 API 白名单。App 对话分享与回放不是主机日志 ZIP 导出。文件限制和主机能力以[使用指南](docs/guide/README.md)为准。

## 旧安装与数据

同包名覆盖更新需要兼容的原签名与合适的递增构建号。缺少原签名时可使用下文的独立并行包，保留旧应用及其数据；不要通过卸载旧应用来解决签名冲突。

升级不会自动删除、重置、上传或迁移旧主目录、对话、工作区、插件及凭据。旧本机选择只会失效，私有数据仍保留；新版不能运行旧环境，也没有自动迁移或清理向导。手动迁移前先核验外部备份，再检查目标主机的路径、配置和权限。详见[升级与旧本地数据](docs/guide/zh/04-legacy-data.md)。

## 从源码构建

所有命令从仓库根目录运行。需要 Git、Python 3、Flutter/Dart、**JDK 17** 和 Android SDK（含所需构建工具及许可）；保留完整项目资源和依赖锁。

- [CI 配置](.github/workflows/ci.yml)钉住 Flutter **3.47.7**；历史 Windows 本地验证使用 **3.47.9 / Dart 3.13.7**。
- [应用 SDK 约束](app/pubspec.yaml)为 Dart **`^3.13.5`**。使用满足该约束的 Flutter 工具链。
- 将 Flutter 和 Java 加入 `PATH`，设置 `JAVA_HOME`、`ANDROID_HOME`（需要时也设置 `ANDROID_SDK_ROOT`）。不需要生成手机 Linux/rootfs。

```text
git clone https://github.com/jesongit/dsh-go-lite.git
cd dsh-go-lite
```

公开源码可直接克隆；推送修改需要仓库写权限。不要在克隆 URL、命令或仓库中写入密码、令牌或签名密钥。

Windows / PowerShell：

```powershell
python tooling/build_apk.py -f arm64 --keep-daemon
```

Linux x86_64 / Bash（已配置工具链）：

```bash
bash tooling/build-apk.sh -f arm64 --keep-daemon
```

Linux 可按需先使用 [setup-toolchain.sh](tooling/setup-toolchain.sh)，再加载其生成的 `tooling/env.sh`；该安装脚本面向 Linux，不用于原生 Windows。x86_64 模拟器将构建命令中的 `-f arm64` 改为 `-f x64`。

arm64 标准输出为 `app/build/app/outputs/flutter-apk/app-arm64-release.apk`；x64 对应 `app-x64-release.apk`。脚本生成构建号，依赖解析可能需要联网；`--keep-daemon` 保留 Gradle daemon。

未提供 `app/android/key.properties` 时，release 构建沿用 **debug 签名回退**。同包名覆盖已有安装仍需原签名密钥（或兼容的合法签名 lineage）；本地 debug 签名不等于上游正式签名。不要提交密钥或密码。

## 并行安装远程测试版

[Gradle 配置](app/android/app/build.gradle.kts)通过本次构建显式传入的 `dshParallelInstall=true` 启用独立包名 `io.github.ccch1mneyyy.dsh_app.remote_test`，普通包仍为 `io.github.ccch1mneyyy.dsh_app`。源码快照已包含 `app/android/app/src/parallel/` overlay，分别隔离 provider authorities、快捷方式目标和应用名称，保留原 namespace 与签名策略。

**标准包和并行包都输出同一个 `app-arm64-release.apk` 路径。每次构建后立即复制为不同文件名，再开始下一次构建。** 下例先保存已生成的标准包，再构建和保存并行包；目标文件名已有内容时请另选名称：

```powershell
Copy-Item app/build/app/outputs/flutter-apk/app-arm64-release.apk ./app-arm64-standard-release.apk
python tooling/build_apk.py -f arm64 --keep-daemon -- --android-project-arg=dshParallelInstall=true
Copy-Item app/build/app/outputs/flutter-apk/app-arm64-release.apk ./app-arm64-remote-test-release.apk
adb install ./app-arm64-remote-test-release.apk
```

若只构建并行版，从上例的 `python` 行开始。使用这个已验证的显式参数；环境变量形式曾未生效，不作为构建方法。普通构建不传该参数即可。

并行包保留旧应用及数据，两套主机配置、私有数据和系统授权相互独立，需要重新配置；不会自动导入或上传旧数据。两者都能处理 `dshgo` 链接，Android 可能询问用哪个应用打开。详见[并行安装验证记录](docs/maintenance/parallel-install-validation.md)。

## 已有验证与未完成项

以下是随快照保留的**历史本地证据**，不是本仓库 CI 全绿或当前设备验证结论；这次 README 更新没有重新运行构建或测试。

| 检查 | 已记录结果 |
|---|---|
| App 静态分析 | `flutter analyze --no-pub` 零问题 |
| 远程/主机/状态等代表性行为测试 | 1,159 通过，16 跳过 |
| 分享/UI 配置/产物文件测试 | 264 通过，2 跳过 |
| Bot 与 Agent 批次 | 503 通过，15 跳过，0 失败 |
| APK 本地检查 | 标准 arm64/x64 和并行 arm64 曾构建；包名、ABI、SDK、签名及无 rootfs 等载荷已有检查记录 |

这些批次有重跑和范围差异，不相加为全量通过数。Windows 金图、文件/符号链接、共享宿主 Node、SDK 和共享 Dart 包等仍有记录在案的基线失败；完整 Flutter 基线未跑完，也没有已核验的全绿 CI。

真实 SSH/Remote 登录与重连、Android 后台通知与桌宠、文件交互、同签名覆盖升级及并行包安装/启动的设备验证尚未完成。细节、跳过原因和历史环境见[纯远程转换验证记录](docs/maintenance/remote-only-validation.md)及[并行验证记录](docs/maintenance/parallel-install-validation.md)。

## 文档与数据处理

- [用户指南](docs/guide/README.md)：连接、聊天、文件、插件、通知、桌宠与外观。
- [架构](docs/architecture.md)、[贡献与验证约定](CONTRIBUTING.md)：开发边界和检查方法；目前不接受外部 PR。
- [插件开发](docs/plugins/README.md)、[SDK](sdk/plugin-kit/README.md)：主机插件与客户端界面集成。

消息、附件和提交的配置会发给明确选择的主机，模型请求由该主机的提供方处理。“发送匿名使用统计”默认开启，可在首次引导或设置中关闭，范围见[常见问题](docs/guide/zh/11-faq.md)。客户端通知、文件、语音和浮窗按功能请求 Android 权限。分享或外发诊断前检查内容与凭据。

其他随附文档中的上游发布、服务、历史路径和本机运行记录应结合本页范围阅读，不代表本仓库提供对应发行包或服务。

## 许可、来源与素材

代码采用 [AGPL-3.0](LICENSE)，`sdk/` 与 `examples/` 保持 **MIT**；第三方组件遵循各自条款。修改和再分发时保留适用的版权、许可证、来源与修改说明，并履行相应源码义务。

- 上游项目：[ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)，原作者 **ccch1mneyyy / DSH-TUI**。
- 远端引擎：[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。
- 吉祥物来源：[DSH-TUI](https://github.com/ccch1mneyyy/dsh-TUI)；远程连接参考 [DSHarness Remote](https://github.com/liguobao/ds-harness-remote)（liguobao / 李国宝）。
- 完整第三方来源及条款：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

**DSH Go 品牌标识、Deepy、鲸娘及相关展示素材不属于 AGPL 代码授权范围**，权利归各自所有者。按 [ASSETS.md](ASSETS.md)，素材可用于构建、测试和运行本仓库；作为修改版或衍生产品再发布时须更换自己的名称和素材。当前仓库名及测试标签并不表示已完成此项工作，也不授予额外素材权利。

本快照独立于上游维护者及 DeepSeek，不代表其官方发行或背书。
