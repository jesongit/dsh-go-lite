# 纯远程客户端转换：实现与验证记录

本记录针对 `D:\code\dsh-Go` 的未提交工作区。基线为 `45e1a7d0a8013e4dc90a5c3a7a19d990ac3d3ee8`，独立基线检出位于 `D:\code\dsh-Go-baseline`。本次没有 commit、push、PR、tag 或发布。

## 实现范围

- 应用只通过既有 SSH 或 DSH Remote 连接宿主；新增明确的未选择状态 `HostRef.none`。首次启动、旧本机选择、无效/已删除 SSH 选择或关闭自动连接时，不启动替代连接，也不选择其他保存的主机。
- 删除手机 Linux/rootfs、PRoot、Direct、运行时安装/更新/启动/日志/安全模式及对应 Android 服务、接收器、依赖和资源。删除本地 DeepSeek 登录、AI 手机操控、无障碍操控与仅依赖本地运行时的桌宠语音路径。
- 保留远程聊天、工作区、审批、插件、文件预览/缓存/打开/保存/分享、客户端通知与桌宠、主题、系统语音及既有远程转写。未增加远程手机操控或补齐其他传输能力。
- 通用 Android 接口移至 `dsh/platform`；文件原生入口限定为应用缓存内的规范化路径，FileProvider 仅暴露产物/更新缓存。旧 rootfs 不再作为文件入口或失败回退。
- 共享宿主补丁、HTTP bridge、媒体插件、认证 bridge 和插件 SDK 保留；宿主测试依赖改由独立、固定版本的 `runtime/prepare-host.py` 准备。补丁 pins、客户端包源码和依赖锁未升级。
- 增加 Windows APK 构建入口，并同步 CI、双语用户文案/指南/支持技能/许可证分发声明及其生成物。保持版本名、构建号公式、arm64/x64、minSdk 26、targetSdk 28 和既有签名回退策略。

## 旧数据与升级

旧本地环境、配置和安全存储中的凭据留在原位置；没有递归清理、重置、导出或上传旧数据的迁移步骤。启动迁移只移除失效的“当前本机”选择指针，不把旧本地会话当作未选择主机的会话恢复。仍可使用的 SSH 配置、DSH Remote 账户和用户客户端偏好沿用原存储契约。

当前测试环境没有维护者签名文件，构建使用仓库原有的 Android Debug 签名回退。该包用于本地验证；覆盖其他签名的已安装版本需要使用同一原签名重新构建。不得以卸载现有应用作为保留旧数据的验证方法。

## 构建与产物

最终两个 Release flavor 均构建成功，版本统一为 **1.0.11+11060641**，包名为 `io.github.ccch1mneyyy.dsh_app`。`aapt2 dump badging` 复核 minSdk 26 / targetSdk 28 和单独 ABI；`apksigner verify --verbose --print-certs` 两包均通过 v2 签名验证，证书为 `C=US, O=Android, CN=Android Debug`。`zipalign -c -P 16 4` 两包退出码均为 0，未修改归档。

| 产物 | 字节数 | ABI | SHA-256 |
|---|---:|---|---|
| `app/build/app/outputs/flutter-apk/app-arm64-release.apk` | 58,795,304 | arm64-v8a | `a32daf36571a4035536fd1565b7783487d268a28ca9bc5c1cfd3011795571d26` |
| `app/build/app/outputs/flutter-apk/app-x64-release.apk` | 64,574,633 | x86_64 | `418d46a0d02b24d80f265bab1c15e37d39296b336287c913322a808303259fcb` |

归档检查确认：两包均没有 rootfs、PRoot、libtalloc、Node、`assets/runtime/` 或旧 `assets/engine/auth/` 载荷，DEX 中没有旧应用 `runtime/`、`phone/` 包名。各 ABI 保留的原生库为 libapp、libdartjni、libdatastore_shared_counter、libflutter 和 libjingle_peerconnection_so。最终 APK 只对应源代码和文案冻结后的构建；后续编辑限于测试与验证记录。

实际使用的 Windows 构建命令：

```powershell
$env:JAVA_HOME = 'D:\Scoop\apps\openjdk17\current'
$env:PATH = 'D:\Scoop\apps\flutter\current\bin;' + $env:JAVA_HOME + '\bin;' + $env:PATH
$env:ANDROID_HOME = 'D:\Scoop\apps\android-clt\current'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_OPTS = '-Dorg.gradle.project.kotlin.incremental=false'
python tooling/build_apk.py -f all --keep-daemon
```

Kotlin incremental 的关闭仅限本次命令环境，用于解决 Windows 上 Pub 缓存在 C 盘、项目在 D 盘时的增量缓存错误，没有修改仓库 Gradle 策略。首次 release 打包还发现并移除了已失去用途的 `android:extractNativeLibs="true"`；该声明在移除旧 native 打包配置后会被 AGP 拒绝。

## 本地验证台账

环境：Windows；Flutter 3.47.9 / Dart 3.13.7；JDK 17。Widget 测试通过 `DSH_TEST_FONT_DIR=D:\code\dsh-Go-test-fonts` 使用 Noto Sans CJK Sans2.004。此处的桌面图像结果不能替代 Linux CI 或 Android 真机结果。

| 检查 | 原始基线 | 当前工作区 | 说明 |
|---|---|---|---|
| 应用静态分析 | `flutter analyze --no-pub` 零问题 | 最终完整 `flutter analyze --no-pub` 零问题，退出码 0 | 对源码冻结后的当前工作区执行，不以早期编译中的临时错误充当最终结果 |
| 远程/主机/状态/权限/服务商/搜索/系统入口及四个聊天回归文件 | 原始全量基线未完成，见下文 | 行为覆盖并集 1,159 项通过，16 项跳过；另 14 项有实际界面变化的金图通过 | 16 跳过为 Windows 无 POSIX shell 的 10 项及需显式启用真实 SSH 的 6 项；不重复相加重跑次数 |
| 首启/迁移重点 | — | 59 项通过 | 含未选择状态、旧本机、非法指针、显式选择竞态、删除主机不回退、旧绑定/未绑定会话等 |
| 分享/UI 配置/产物文件聚焦行为 | — | 264 通过，2 跳过 | 2 项需要 POSIX shell；含全部 30 项 Node checker 对照、远程缓存/版本/并发/路径/保存重叠及未选择时客户端偏好回退 |
| 分享与文件金图 | — | 改动的分享 10 项、远程 Markdown 2 项通过；原 PDF 2 项保持原图并通过 | 未因 Windows 字形差异更新其余文件/QR/卡片图像 |
| 通知/桌宠/Star | — | 核心与聚焦行为已通过，含最终重跑 35 项、背景提示 13 项及覆盖层引导 1 项 | 另一个 widget 批次通过 108 项；重跑计数有重叠，不当作独立总数。7 个未改变界面的金图保留，Windows 比较仍有字形差异 |
| 诊断/用量 | — | 用量核心 34、诊断核心 39、手动导出及非金图界面/用量 39 项通过 | 未自动外发诊断；手动导出路径处理有 Windows 回归覆盖 |
| 通用客户端/插件/工作区/启动/终端及四个主线回归文件 | — | 串行首批 546 通过/1 跳过；失败子集重跑 164 通过，最后 5 项通过 | 重跑计数重叠，不相加。17 个行为/夹具问题已闭环；保留 20 个未改变界面的 Windows 金图差异及 1 个原始 WebRTC 资产 checksum 失败。终端不支持提示的 2 张实际改文案金图单独刷新并通过；XLSX 预览、Web 快捷入口、社区和两组启动设置逻辑已通过 |
| 聊天/设置界面收尾 | — | 精确两文件 7 项通过；设置/聊天聚焦批次 111 项通过；其余聊天首批 387 通过，失败相关三文件最终 49 项通过；最终 6 项预期截图比较通过 | 计数有重叠，不相加。行为断言未放宽；此前两项基线通过的聊天测试串行重跑原样通过。截图只保留实际变化的 20 张既有图和 8 张新的纯远程界面图，无关重绘已恢复原字节；原插件 composer owner 和关闭岛屿仍保留全局面板的回归均通过。清理后产物预览 2 张图已恢复正确的远程路径，并再次通过独立 2/2 比较与目视检查；未改动生产代码 |
| Bot 与 Agent | — | 最终整批 503 通过/15 跳过/0 失败，退出码 0 | 15 跳过为 14 项既有 DSBOT_GOLDENS 开关比较和 1 项 LINEAGE_MEASURE 可选测量；其他纯金图名称按命令过滤。先前两项主机身份/旧标题夹具失败均通过，未修改生产代码 |
| Android JVM | 880 项，70 失败 | 275 项，2 失败，1 跳过 | 两个最终失败均在基线复现：`LegacyDownloadsTest` 的 Windows AccessDenied、`ClipPathTest` 的符号链接权限。新增 CachedFiles 规范路径边界通过；符号链接创建不可用时明确跳过 |
| 固定宿主准备/补丁/认证 | — | 宿主依赖准备通过；补丁 10/10、认证 20/20 通过 | 实际执行固定包安装与完整补丁链，不依赖手机运行时构建物 |
| 共享宿主 Node 全量 | 1,118 项：1,030 通过，70 失败，18 跳过 | 1,124 项：1,051 通过，55 失败，18 跳过 | 最终 54 个失败名称同基线；另外 1 个音频边沿定时测试脱离并行争用单独重跑通过。基线还有被本次移除的本地 boot 测试，不能用失败数下降证明质量提升 |
| 插件 SDK `npm test` | 89 项：84 通过，5 失败 | 89 项：85 通过，4 失败 | 最终 4 项均在初始基线存在：Windows 符号链接 EPERM、CRLF 对照生成物/前言/类型声明。额外生成物漂移经正式生成器同步 |
| Python 构建工具 | — | 46 项通过，1 个既有可选 zstd 跳过 | 包含 Windows/Bash 构建参数、版本/ABI 及离线 release 工具契约 |
| Python 应用工具 | 宠物资源单文件 14 项中 1 失败 | 全部 33 项中 1 失败 | 同一 `deepy-whale/building.png` 字节重建差异在原始基线复现；未重绘无关宠物资源 |
| 共享 Dart 包 | 两包分析通过；`dsh_client` 656 通过/31 跳过/1 失败；`dsh_remote` 454 通过/4 跳过/3 失败 | 包源码和依赖锁未改；未重复运行 | Client 失败为 Windows 尾随空格文件名不能区分；Remote 3 失败为 compact history 配置等待、fresh descriptor 激活和非法传输帧分配释放。以原始完整日志为据，没有将这些原有失败报告为通过 |
| 生成物与差异卫生 | — | l10n 44 parts / 4,821 keys；guide 26 文件；SDK skill 与 replay 生成检查通过；`git diff --check` 通过 | 不手改 l10n/指南生成结果；只刷新真正改变的截图 |

WebRTC NOTICE 原始字节断言没有被放宽：当前与独立基线资产都为 803,520 字节、15,162 个 CRLF，raw SHA-256 均为 `06916e49c01b1fbf11b400816da48483ab54c0e25117848f27fdc9230923f0b4`；只有转换 LF 后才匹配原测试钉住的 `d1f9382c6878ac024155fd6d44a5977329108bb8b0a01cea40e4a2f1d7de252e`。保留源资产及 checksum 契约，将此项记录为当前 Windows 检出的既有失败。

基线 Flutter 全量测试运行到日志最后一条 `21:11 +6415 ~308 -741` 后中止，**没有全量完成**。其中包含大量 Windows 字形栅格、平台文件/符号链接行为和少数超时；没有把全部 741 个失败统一归因为金图，也没有宣称原始或最终 Flutter 全量套件全绿。对应日志保留在 `D:\code\dsh-Go-baseline-tests.txt`。

最终改动验证采用串行聚焦批次。曾同时启动的 Flutter 测试争用同一 `build/test_cache`，取消上层命令后还遗留测试子进程；已停止这些批次并仅清理命令行能够确认属于本次工作区的测试进程。中断批次保留日志，但不充当最终通过证据。

# Review verdict

**结论**：Merge with conditions；代码转换的本地证据已建立，发行前仍须闭环设备验证。本次没有合并或发布操作。

**模式**：Review；**对象**：`D:\code\dsh-Go` 未提交工作区；**基线/Head**：`45e1a7d0a8013e4dc90a5c3a7a19d990ac3d3ee8` 加当前未提交改动；**信任级别**：trusted-local。

## Findings

当前已审实现范围没有遗留的、可证实由本次改动引入的阻断发现。集成中发现的 native 打包声明冲突、未知 SSH 选择/旧会话回退、文件规范路径边界、主机身份夹具不一致和旧本机导航入口已经修正并有对应验证。此结论限于本记录所列读码和测试范围，不能据此推断真机或全量套件通过。

## Clarifying questions

没有阻碍本地实现交付的待答问题。当前没有可用 ADB 设备，也未使用真实远程账户或维护者签名密钥，设备和覆盖更新结果没有运行证据。

## Validation record

见上表及构建命令。所有最终结果对应上述基线加当前未提交工作区；没有已核验的远端 CI 状态，不能标记 `CI OK`。

关键实际命令（在相应目录运行；不是本次全部失败子集重跑命令的穷举）：

```powershell
# app 目录；Windows 下直接调用 Dart，避免 flutter.bat 丢失正则中的 !。
flutter analyze --no-pub
$env:DSH_TEST_FONT_DIR = 'D:\code\dsh-Go-test-fonts'
$env:FLUTTER_ROOT = 'D:\Scoop\apps\flutter\current'
& "$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin\dart.exe" "$env:FLUTTER_ROOT\bin\cache\flutter_tools.snapshot" test --no-pub --concurrency=2 test/bots test/agents --name '^(?!golden:|[a-z_]+ \((light|dark)\)).*'

# 仓库根目录；JVM 在当前 JDK/Android SDK 环境执行。
app/android/gradlew.bat -p app/android --no-daemon '-Pkotlin.incremental=false' :app:testArm64DebugUnitTest
python runtime/prepare-host.py --out D:/code/dsh-Go-host-fixture-final
$hostFixture = Get-Content 'D:\code\dsh-Go-host-fixture-final\host-env.json' | ConvertFrom-Json
foreach ($field in $hostFixture.PSObject.Properties) { Set-Item -LiteralPath "Env:$($field.Name)" -Value $field.Value }
$hostTests = Get-ChildItem runtime/tests/*.test.mjs | ForEach-Object FullName
node --test @hostTests
python -m unittest discover -s tooling -p 'test_*.py'
python -m unittest discover -s app/tool -p 'test_*.py'
python app/tool/l10n_merge.py --check
python app/tool/guide_sync.py --check
node sdk/plugin-kit/scripts/sync-skill.mjs --check
python app/tool/make_replay_viewer.py --check
```

最终日志包括 `D:\code\dsh-Go-analyze-final.txt`、`D:\code\dsh-Go-apk-build-all-final.txt`、`D:\code\dsh-Go-host-tests-{baseline,final}.txt`、`D:\code\dsh-Go-scoped-final.txt`、`D:\code\dsh-Go-core-tests-run5.txt`、`D:\code\dsh-Go-core-tests-retry1.txt` 和 `D:\code\dsh-Go-core-tests-system-final.txt`；完整核心批次命令/较早中断记录在 `D:\code\dsh-Go-core-validation-20261106-session-a725.md`。

## Coverage and residual risk

已审启动/选择/迁移、连接创建与清理、远程操作的主机归属、原生通道/服务/清单/文件暴露、共享宿主准备、插件/认证保留边界、文案与构建。未对每个未改动页面和第三方依赖重新进行完整审计；未运行任何真实设备、真实远程登录/恢复连接或真实插件宿主操作。桌面有限计时和图像结果有平台限制。

## Cleanup conditions

1. **设备门槛（未运行）**：在 Android 上验证首次安装无本机选项、无选择时仅显示远程入口；验证同签名覆盖旧安装后数据仍在、旧本机指针变为未选择且不自动发送旧凭据/文件。
2. **连接门槛（未运行）**：真实 SSH 的建连、主机密钥确认、断线重连、后台恢复、切换与删除；真实 DSH Remote 的登录、选择、局域网/WebRTC/中继已有路径、审批/问题及会话/插件状态的主机归属。
3. **系统集成门槛（未运行）**：前后台通知、点击定位、桌宠覆盖层/单次审批、厂商后台限制、语音；文件预览/外部打开/下载/分享/PDF；旧 rootfs 不可通过缓存通道访问。
4. **发行门槛（未运行）**：Linux CI 的完整 Flutter/共享测试与金图、维护者同签名正式包、真实覆盖更新及回滚/备份流程。保留本地已记录的失败与跳过，不把 Debug 签名验证包当成正式发布包。
