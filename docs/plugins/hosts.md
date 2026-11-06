# 主机覆盖、安装与降级

[English](en/hosts.md)

dsh-go 通过 SSH 或 DSH Remote 连接远程 DSH，不再提供手机本机引擎。工具卡随对话记录传输；其余原生插槽需要在主机安装兼容的 `dsh-go-bridge`，并通过 HTTP 访问。

| | 工具卡 | 胶囊、菜单、状态条、面板及媒体 | 网页插件 |
|---|---|---|---|
| SSH 主机 | ✅ | 安装兼容 bridge 后可用 | 可通过 SSH 转发打开；具体岛屿受现有规划器限制 |
| DSH Remote 主机 | ✅，随工具记录 | ❌，当前 carrier 不放行 `/dsh-go/*` | ❌，没有可用 HTTP 页面通道 |

DSH Remote 的 LAN/P2P、TURN、Relay 只改变传输路径，不解除端点限制。市场、插件列表和开关沿用已有接口；安装、卸载需要在那台主机操作。本次不补齐两种连接的能力差异。

## 在主机安装开发目录

插件是主机上的 npm 包目录，按实际运行 DSH 的机器上的绝对路径安装：

```sh
dsh plugin --profile web add /绝对路径/my-plugin
```

使用主机实际运行的 profile（通常为 `web`）。手机或开发电脑上的路径不会自动复制过去。目录安装可能链接源目录，必须保留它；修改 `package.json` 的 `dshGo` 后，bridge 会按文件修改时间重读。修改已加载的 JavaScript 后，先构建实际入口，再按主机自己的流程重启 DSH；重启会中断该主机的任务。卸载后重新安装不能保证清空模块缓存。

```sh
dsh plugin --profile web remove 包名
```

`engines.dsh` 应明确兼容版本；不能用手机端设置绕过主机的版本或权限检查。安装 bridge 时使用 [共享 bridge 包](../../runtime/bridge/dsh-go-bridge/)，按其配置和权限要求在远端启用，不要复制旧手机主目录及凭据来安装它。

## 降级

| 情形 | App 行为 |
|---|---|
| SSH 未安装 bridge | 保留工具卡；支持的网页部分可在 DSH Web 打开 |
| DSH Remote | 保留工具卡与现有 RPC 功能；不显示不可达的 bridge/Web 功能 |
| `minApp` 太高或协议版本不支持 | 原生部分不显示，并提示版本问题 |
| 单项声明错误 | 只丢弃该项，在原生界面诊断中报告 |
| 插件运行中连续违规 | 按现有规则降级；在主机修复并重启或重新启用 |
| 宿主未注册处理或 App 不识别组件 | 禁用该项或显示占位，其余可用内容保留 |

`dshGo` 清单和 `ctx.dshGo` 只为 App 提供声明，插件逻辑仍在远端执行。一个插件可以同时提供网页半侧和原生声明，DSH Web 与 App 各自使用对应界面。共享 bridge、插件 SDK 和媒体插件继续保留。
