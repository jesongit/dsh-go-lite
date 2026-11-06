# Remote hosts

DSH runs on your computer or server. DSH Go connects through SSH or DSH Remote; chats, workspaces, models and plugins belong to that host. The phone does not install or start a DSH runtime.

## First launch and no host selected

Add and select a remote host before sending a message. First launch without a host and an old configuration selecting the removed local host both start with no host selected. Deleting the selected host or signing out of its DSH Remote account returns to that state. The app never chooses a different saved or online host for you.

When **Connect to the last host** is enabled, opening the app attempts to reconnect to the valid remote host you selected last. With it off, connect manually. An offline or untrusted host stays unavailable until you resolve its connection; it does not redirect your chats to another host.

An old local home stays private on the phone and is not uploaded or deleted. See [Upgrading and legacy local data](04-legacy-data.md).

## Switch hosts

Open the chat list and tap the host name at the bottom to open **Switch host**, then choose a remote host. With none saved, tap **Connect a computer or server**; otherwise tap **Manage remote hosts**. Tap the icon beside the name for connection details, the current route and latency where supported.

<!-- nav: commonSettings,commonRemoteHost -->
`Settings › Remote host` · [Open](dshgo://open/remote)

## Add an SSH host

The host needs SSH enabled and DSH installed (`npm i -g @deepseek-ai/dsh`).

1. Tap **Add SSH host**.
2. Enter **Host** and **Username**. **Port** defaults to 22. The name is optional.
3. Choose **Password** or **Private key**. You can **Import from file**, with a **Private key passphrase (optional)**. Saved credentials stay on this phone.
4. **Start command** defaults to `dsh web`; installations using nvm may need its full path. **Working directory (optional)** sets where new chats start.
5. Tap **Test connection**. At **Trust this host?**, compare the fingerprint with the host and choose **Trust and connect** only if it matches.
6. Tap **Save**, then select the host.

Testing starts DSH on the remote host and leaves it running. Use **Edit** to change a host; **Delete this host** removes its saved connection settings and credentials from the phone, leaving remote DSH and its chats intact. If it was selected, no host is selected afterwards.

SSH forwards the remote web service to a loopback port on the phone. This tunnel supports HTTP APIs and embedded DSH Web; it does not run a local DSH engine.

## DSH Remote

1. Install and sign in to the Remote plugin on the host's DSH.
2. On the remote hosts page, select the same sign-in provider and account. If only **Sign in in browser** appears, use that button.
3. Choose an online host. On first connection, compare its identity fingerprint with the Remote plugin before tapping **Trust and connect**.

This account sign-in is for DSH Remote connections. The old local-engine DeepSeek login is no longer available; configure model credentials on the selected host.

The encrypted connection automatically tries LAN/P2P, TURN, then Relay, subject to server and host support. Tap its route label for the actual route, connection time, available latency and fallback reason. WebRTC details show IPv4/IPv6 and UDP/TCP for selected candidates without exposing raw IP addresses. A direct path does not remove the API limits below.

<!-- nav: commonSettings,commonRemoteHost,remoteCompactHistory -->
`Settings › Remote host › Compact history`

**Compact history** is off by default. Supporting hosts summarize historical tool arguments and output during transfer; message text, live replies, approvals and original host records stay unchanged. Select another host and return, or restart the app, to apply a change. Automatic reconnects keep the original mode. Older hosts send full history; SSH is unaffected.

DSH Remote connects to one host at a time; switching disconnects the previous one.

## Current feature limits

| Feature | SSH | DSH Remote |
|---|---|---|
| Chat, workspaces and approvals | Existing host APIs | Supported host APIs |
| File attachments | Remote upload API | Compatible hosts negotiate file upload; older hosts accept images only |
| Plugin lists, market and enable/disable | Available | Existing allowed APIs |
| Plugin install/uninstall | Available through host APIs | Run commands on the host; not allowed by the current transport |
| Native plugin UI, bridge configuration and media | Requires a compatible dsh-go bridge on the host | HTTP bridge routes are unavailable |
| Embedded DSH Web and plugin WebView | Available through the SSH tunnel | Unavailable, including on a direct path |
| DS Bot and chat-log ZIP export | Requires the host's corresponding APIs | Unavailable with the current transport |
| Skill and personal-instruction file import/export | Not guaranteed; some old paths required the phone runtime | Not guaranteed |

For file-upload limits and failure behavior, see [Chat](01-chat.md). App sharing and replay are separate from the host's ZIP-log export. No remote protocol for AI control of this phone is implemented.
