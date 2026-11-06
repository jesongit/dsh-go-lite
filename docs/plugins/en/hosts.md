# Hosts, installation and fallbacks

[中文](../hosts.md)

dsh-go connects to remote DSH through SSH or DSH Remote. It no longer runs an engine on the phone. Tool cards travel with conversation records; other native slots need a compatible `dsh-go-bridge` installed on the host and reachable over HTTP.

| | Tool cards | Capsules, menus, status, panels and media | Web plugins |
|---|---|---|---|
| SSH host | ✅ | Available with a compatible bridge | Available through SSH forwarding; individual islands remain subject to the existing planner |
| DSH Remote host | ✅, with tool records | ❌, current carrier does not pass `/dsh-go/*` | ❌, no usable HTTP page channel |

DSH Remote's LAN/P2P, TURN and Relay routes change transport, not endpoint limits. Market, lists and enable/disable retain their existing APIs; installation and removal require action on the host. This conversion adds no parity features.

## Install a development directory on the host

A plugin is an npm package directory on the machine running DSH. Install using its actual absolute path there:

```sh
dsh plugin --profile web add /absolute/path/to/my-plugin
```

Use that host's active profile, usually `web`. Paths on your phone or development computer are not copied automatically. A directory install may link its source, so keep the directory. The bridge rereads `package.json` declarations by modification time. After changing loaded JavaScript, build the actual entry point and restart DSH using the host's own workflow; this interrupts tasks there. Removing and reinstalling is not a guarantee that module caches are cleared.

```sh
dsh plugin --profile web remove package-name
```

Declare compatible versions in `engines.dsh`; phone settings cannot bypass the host's version or permission checks. Install and configure the [shared bridge package](../../../runtime/bridge/dsh-go-bridge/) on the remote host, following its configuration and permission requirements. Do not copy an old phone home and its credentials as a bridge installation procedure.

## Fallbacks

| Case | App behavior |
|---|---|
| SSH without the bridge | Tool cards remain; supported web parts can open in DSH Web |
| DSH Remote | Tool cards and existing RPC features remain; unreachable bridge/Web features are unavailable |
| `minApp` too new or unsupported protocol version | Native parts are omitted with a version notice |
| Invalid declaration entry | Only that entry is dropped, with a native UI diagnostic |
| Repeated runtime violations | Existing fallback rules apply; fix and restart or re-enable on the host |
| Missing handler or unknown component | Disabled entry or placeholder; other usable content remains |

The `dshGo` manifest and `ctx.dshGo` provide declarations to the app; plugin logic still runs remotely. A plugin can offer both a web half and native declarations, with DSH Web and the app using their respective interfaces. The shared bridge, plugin SDK and media plugin remain available.
