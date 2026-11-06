# dsh-Go 架构

DSH Go 是 Android 远程 DSH 客户端。Flutter 原生界面通过 SSH 或 DSH Remote 连接电脑、服务器上的 DeepSeek Harness；模型调用、命令、工作区和插件逻辑在所选主机执行。手机不再安装或启动 Linux/rootfs、Node、PRoot、Direct 或本地 DSH，也不提供本机 DeepSeek 登录和 AI 手机操控。

## 技术栈与目录

| 层 | 实现与职责 |
|---|---|
| UI | Flutter + Riverpod；聊天、对话、主机、设置、客户端插件渲染 |
| Android | Kotlin 平台插件；文件打开/保存、媒体、分享、更新安装、通知、后台设置与桌宠浮窗 |
| DSH 客户端 | `packages/dsh_client/`；纯 Dart HTTP/SSE、mux、对话与主机 API |
| 远程传输 | `packages/dsh_remote/`；认证、Noise 加密、LAN/P2P、TURN、Relay 与能力协商 |
| SSH | `app/lib/remote/ssh/`；主机指纹、SSH 登录、远端 `dsh web` 启动和手机 loopback 端口转发 |
| 共享宿主代码 | `runtime/bridge/dsh-go-bridge/`、`runtime/media/dsh-media/`、引擎补丁与宿主测试依赖；供远程主机及 SDK 使用，不是 APK 内的手机执行环境 |
| 插件 SDK | `sdk/plugin-kit/`；协议、作者工具、生成器与示例 |
| 构建 | `tooling/`；工具链、构建号、APK、更新清单和发布资产 |

`app/lib/state/` 管理主机与对话状态；`app/lib/ui/` 提供聊天、远程连接、设置、文件及网页界面。Android 的 `FlutterEngine` 是 UI 执行器；客户端所需的 Flutter/WebRTC 原生库、桌宠前台服务和文件缓存仍需保留。

## 主机选择与启动

- “未选择主机”是正常状态。首次启动没有主机、旧配置选中已移除的本机主机、删除当前主机或退出其 DSH Remote 账号时，回到未选择；不自动选择任意远程主机。
- 自动连接开启时，只尝试有效的上次远程目标；关闭后由用户手动连接。离线、认证失败或指纹变化显示实际状态，不用其他主机掩盖失败。
- 对话、最近记录、通知、快捷方式、离线缓存和分享导入都必须保持主机身份；未选择时不得把内容发给默认或碰巧在线的主机。
- 旧本机选择的失效不触发本地数据清理或凭据恢复到远程。App 自身外观等设置可在没有主机时使用；主机设置必须来自当前连接。

## 传输与能力边界

| 能力 | SSH | DSH Remote |
|---|---|---|
| 聊天、对话、工作区与审批 | 使用远端已有 API | 使用 carrier 放行的 RPC 与主机实际能力 |
| 文件附件 | 远端上传 API | 支持 `workspace.upload.v1` 的主机协商后可用；旧主机仅图片；限制取决于主机和路径 |
| 插件清单、市场与开关 | 已有接口 | 现有白名单支持的接口 |
| 插件安装/卸载 | 已有远端接口 | 当前白名单未放行，需在主机操作 |
| 原生插件界面、桥接配置与素材 | 远端安装兼容 bridge 后可用 | 没有通用 HTTP carrier，`/dsh-go/*` 不可达 |
| DSH Web 与插件 WebView | 手机 loopback 转发远端页面 | 当前不可用；LAN/P2P 也不等于开放 HTTP |
| DS Bot | 远端 HTTP/SSE 接口 | 客户端虽有 RPC 适配，当前白名单仍未放行 |
| 对话日志 ZIP 导出 | 远端 HTTP 接口 | 当前不可用；App 对话分享是另一条路径 |
| 技能/个人指令文件导入导出 | 部分旧实现依赖手机 guest 文件系统，不能承诺远程可用 | 同样不承诺 |

SSH 的 `127.0.0.1:<转发端口>` 是远程隧道入口，不能作为手机本地 DSH 删除。它承载 HTTP API、cookie/token 握手及 WebView。DSH Remote 在连接时协商 LAN/P2P、TURN、Relay 和上传等能力；实际路径可变，端点白名单仍有效。本次不补齐两种连接的功能差异。

## 插件与共享代码

插件代码在主机运行，App 根据对话中的工具卡或 bridge 提供的声明与 JSON 视图渲染原生 UI。`runtime/` 不可整目录删除：SDK 生成器使用 bridge 源码，独立媒体插件及共享宿主补丁/测试仍有用途。改协议时检查 App、bridge、SDK 与远端兼容性，按对应生成器同步，见 [插件主机覆盖](plugins/hosts.md)。

指南源文件在 `docs/guide/`，由 `python app/tool/guide_sync.py` 生成 App 资源；保留资源不代表自动安装到远程主机。不得把旧本机 home、技能或凭据自动上传到远端。

## 打包、升级与旧数据

APK 保留 `arm64` / `x64` flavor、应用包名、签名、递增 versionCode、正式文件名及更新清单契约。Flutter/WebRTC 含原生库，移除 rootfs 不代表可以忽略 ABI。构建无需生成手机 Linux 运行时；使用 [README](../README.md) 和 [发布说明](release.md) 的 APK 入口。此次不升级依赖或 targetSdk；targetSdk 28 是当前配置，不再以执行私有目录文件作为产品要求。

覆盖升级保留旧 App 私有目录，包括旧主目录及中断安装/重置可能留下的状态；不静默 reset、不删整个 App 数据目录、不自动上传凭据。没有实现自动迁移或旧数据清理向导。需要用户明确手动迁移：先外部备份，核验签名兼容，再按远端环境处理绝对路径、工作区和插件。不同签名的包不能直接覆盖；不要用卸载解决签名冲突而丢失唯一数据。见 [升级与旧本地数据](guide/zh/04-legacy-data.md)。

## 验证

按 [CONTRIBUTING](../CONTRIBUTING.md) 运行相应检查并记录实际结果。重点覆盖无主机、旧本机选择、删除最后主机、Remote 登出、禁用自动连接、离线/重连、切换主机和正确的通知/快捷方式目标；检查 SSH 网页、远程插件、文件与分享。APK 应无 rootfs/PRoot/Direct 手机载荷，保留客户端原生库。覆盖升级、真实 SSH/Remote、后台通知和桌宠仍需要 Android 真机及获授权的主机；桌面结果不能替代。

早期架构和实施记录保存在 `docs/design/`、`docs/testing/`、`docs/maintenance/` 和 [历史更新日志](changelog.md)，其中的本地运行、登录及手机操控描述不是当前使用说明。
