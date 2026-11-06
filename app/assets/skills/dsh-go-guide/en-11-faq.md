# Troubleshooting

## Messages will not send, or no reply arrives

Check the host at the bottom of the chat list. With no selection, add and explicitly choose a [remote host](03-engine-hosts.md). An old local selection is no longer usable and never selects another host automatically.

For a saved host, follow the connection page's reason: reconnect, sign in again or verify its fingerprint. Check that remote DSH is running and that a model is configured on that host. A host or transport that lacks an API cannot gain it by reinstalling the phone app.

<!-- nav: commonSettings,phoneEngineDiagnostics -->
`Settings › Diagnostics` · [Open](dshgo://open/diagnostics)

Export diagnostics when reporting a problem. Review logs and archives manually before sharing; automatic redaction cannot guarantee that all private information is removed. To share diagnostics with an AI on a remote host, explicitly select what to send; the old local-engine diagnostics file is not uploaded automatically.

## Background alerts do not arrive

<!-- nav: commonSettings,phoneEngineKeepAlive -->
`Settings › Background running` · [Open](dshgo://open/background)

Follow the battery optimization and phone-maker guidance. Remote alerts need the app running with a live connection. Also allow DSH Go notifications in Android settings and enable the alert types you want under **Notifications**. Android can still stop the app or its connection; this does not stop DSH running on the remote computer.

## Where did the local engine and phone control go?

The app is now a remote client. Local runtime installation, startup, reset, Safe mode, Direct launch, local DeepSeek login and AI phone control are removed. There is no implemented remote substitute for phone control. Old private data is preserved; see [Upgrading and legacy local data](04-legacy-data.md) before changing or uninstalling an installation.

## The pet is gone

- In chats, choose a pet if **None** is selected; if hidden for an hour, tap **Show now**.
- Outside the app, enable **Show outside the app** and Android's display-over-other-apps permission. **When active** hides it after five quiet minutes; tap **Restore** if hidden for today. The pet hides while the app is in the foreground.
- Alerts and pet actions still require the correct remote host and a live connection. See [Pets](06-pets.md).

## A plugin is installed but its interface is missing

Check it is enabled and restart DSH on the host when required. Native plugin UI requires a compatible dsh-go bridge installed on an SSH host. DSH Remote currently cannot reach its HTTP routes, even over LAN/P2P. Some display places may be disabled in plugin details. SSH can open supported web entries; DSH Remote cannot open DSH Web in the app. See [Plugins](08-plugins.md).

## What the app sends

<!-- nav: commonSettings,hubPrivacy,usageStatsTitle -->
`Settings › Privacy and sharing › Send anonymous usage stats` · [Open](dshgo://open/usage-stats)

On by default, with a switch during first-run setup and in Settings. While enabled, the app sends anonymous daily usage summaries at most once a day: app/Android version, CPU architecture, phone maker (not model), interface language and feature counts such as messages, voice input, generation, sharing and installed plugins. A random ID distinguishes installations and changes every 90 days. The old local-start and phone-control fields are legacy schema fields, not evidence of a running phone engine or screen access.

The usage report excludes accounts, API keys, chats, files, prompts, host addresses, phone numbers and IMEI. Turning it off stops reporting and deletes the local counts and random ID. Chat messages and attachments are sent separately to the host you choose; model and plugin data handling depends on that host and its providers.

## The guide does not match the screen

Compare **Version** in Settings with the [guide index](../README.md). Host APIs and available UI also vary by engine and plugin version. Do not follow old local-runtime instructions as a recovery procedure for the current app.
