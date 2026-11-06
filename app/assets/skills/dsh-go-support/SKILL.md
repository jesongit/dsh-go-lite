---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-support
description: dsh-go 远程客户端的排障与反馈：根据用户明确提供的客户端诊断、所选主机和实际连接状态定位问题，生成脱敏环境摘要与 issue 草稿。用户说卡顿、发热、耗电、连不上、闪退、更新装不上、插件不生效或要反馈 bug 时加载。Diagnose DSH Go remote-client problems from explicitly supplied diagnostics and host evidence.
whenToUse: The person reports a DSH Go client problem or asks for an issue draft. Not for changing app UI (dsh-go-ui) or writing a plugin (dsh-go-plugin).
---

# dsh-go 排障与反馈 · Remote client support

先取证再判断。DSH Go 通过 SSH 或 DSH Remote 连接电脑/服务器上的 DSH，不在手机运行 DSH、Linux、PRoot 或 Direct，也不提供本机 DeepSeek 登录和 AI 手机操控。不要建议安装、重置、启动手机运行环境或切换安全模式来修复当前客户端。

## 1. 使用用户提供的诊断

当前没有自动把手机诊断写入远程 `$DSH_HOME` 的机制。不要假定主机上存在 `dsh-app/diagnostics.md`，也不要把主机日志当成手机状态。

- 先读用户已明确提供的诊断附件、截图和日志；有事实可读时不要重复索要。
- 缺少必要证据时，让用户在「设置 → 诊断」手动导出诊断包，再由用户决定是否附到对话或问题报告中。只要与症状相关的部分，不索取真实凭据或整份旧主目录。
- 外发前人工检查路径、账号名、设备信息、日志及截图；自动脱敏不能保证清除所有隐私。先取得用户对内容及目标的明确授权，不能自行上传或代发 issue。
- 区分 App 版本/构建号、Android/ABI、主机 DSH/插件版本、SSH 或 DSH Remote、实际 LAN/P2P/TURN/Relay 路径，以及已验证和未验证的范围。没有的字段标为未知，不猜测。

## 2. 按症状检查

### 无主机、发不出消息、一直重连

首次无主机、旧本机选择、删除当前主机或退出相应 Remote 账号后，未选择是正常状态。让用户明确选择目标；不得自动连接另一台已保存或在线主机。自动连接关闭时需要手动连接。

SSH：核对地址、端口、用户名、指纹和主机上 DSH 是否可运行。手机的 loopback 端口是 SSH 转发，不能作为本机引擎删除或暴露到公网。

DSH Remote：核对手机与主机使用的账号/登录提供方、主机插件是否在线、信任指纹和实际错误。网络路径回落并不保证一定连得上。两个 DSH 实例共用同一主目录可能互相替换连接，但只能在日志支持时作为原因。需要主机证据时，只在用户授权的主机查相关日志。

### 功能缺失或插件不显示

- 插件、工作区与模型属于所选远程主机，先核对目标和 profile，再看安装/启用及主机返回的加载状态。
- SSH 原生插件界面、桥接配置与媒体需要远端安装兼容的 dsh-go bridge；DSH Remote 当前无法访问这些 HTTP 路由，LAN/P2P 直连也不解除限制。
- DSH Remote 保留已有市场/清单/开关 API，但不能从 App 安装或卸载插件、打开 DSH Web、使用 DS Bot 或导出对话日志 ZIP。需要时在主机操作或使用 SSH。
- 文件附件依赖主机协商上传能力和当前路径限制；旧 Remote 主机仅支持图片。不要承诺不限大小或上传失败后消息仍已发送。
- 部分技能和个人指令文件导入/导出没有远程替代，不把保留 UI 或 SDK 等同于接口可用。
- 重启远端 DSH 会中断任务，必须由用户按目标主机流程明确决定。App 不提供远程插件级源码 HMR 保证。

### 卡顿、发热和耗电

区分手机界面渲染、网络传输与主机/模型延迟。查看相关错误、回复长度、代码块数量、性能档位、温度和网络路径。可请用户对比轻量模式、降低动效或刷新率；一次只改一个可回退设置。手机没有 DSH 进程，不把远端 npm/命令负载说成手机本地引擎抢 CPU，也不把持续高温一概视为正常。

### 后台断连、通知或桌宠缺失

提醒需要 App 仍运行、目标主机正确且连接在线。核对 Android 通知、后台网络/电池限制与桌宠的悬浮窗权限；客户端结束不会停止远端 DSH。解释相关设置的后果，由用户自己决定授权，不建议开启已移除的无障碍手机操控服务。

### 更新装不上或旧数据找不到

核对版本、ABI、构建号、下载完整性和签名。不同签名且无兼容 lineage 的包不能覆盖。不要建议直接卸载、清除 App 数据或删除旧运行目录：旧主目录可能仍是唯一副本。

升级不自动删除、上传或迁移旧 home 和凭据，也没有实现自动迁移/旧数据导出向导。需要明确授权、可访问旧数据的兼容安装或获授权恢复方式、已核验的外部备份，再手动迁移选定文件。普通文件管理器不能读取 App 私有目录。备份可能含凭据，不能当公开诊断包；保留文件也不等于远端恢复成功。

## 3. 生成问题报告草稿

用户要求反馈时，提供可粘贴的草稿，由用户提交：

```md
## 环境
- App：<版本> (<构建号>)
- Android / ABI：<已知值或未知>
- 连接：<未选择 / SSH / DSH Remote；路径（如已知）>
- 远程主机：<DSH 与相关插件版本；不公开地址、密钥或账号>

## 现象与影响
<具体操作、触发条件和影响>

## 复现步骤
1. …
2. …

## 期望 / 实际
…

## 证据与验证范围
<必要的脱敏错误/日志、已运行检查、未验证设备或账号范围>
```

不要回显 API Key、token、cookie、验证码、私钥或私人对话。诊断包由用户自己审查和附上，不代替用户发给维护者。没有授权不改系统设置、不安装/卸载、不清数据、不重启主机。证据够复现时就给草稿；不能定位时说明缺口，只提出一个最有用的下一步。

Use the user's language. For English reports, translate the same evidence-based steps and template; do not invent local-runtime repair instructions, host capabilities or a completed data migration.
