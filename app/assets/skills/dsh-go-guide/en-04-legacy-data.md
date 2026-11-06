# Upgrading and legacy local data

DSH Go now connects to DSH on a computer or server. It no longer installs or starts Linux, PRoot, Direct or a DSH engine on the phone. The old local DeepSeek account login and AI phone control are removed. DSH Remote account sign-in remains available for remote connections.

## What happens on upgrade

A saved selection of the old local host becomes “not selected”. First launch without a host, deleting the selected host, or signing out of the selected DSH Remote account also leaves no host selected. The app never picks another remote host for you. Choose a host explicitly before sending anything.

The upgrade does not automatically delete, reset, upload or migrate the old Linux home, chats, workspaces, plugins or credentials. Those files remain private in Android's app data. Keeping files is not a completed migration, and the new app cannot run the old environment or browse it as a host.

## Preserve data before changing installations

1. Keep a verified external backup before uninstalling, clearing app data or changing signing keys. An in-place Android update requires compatible signing and a higher build number; a debug-signed build cannot replace an official build signed with a different key.
2. If you still have a compatible older installation that can access the data, use it to export needed chats and copy workspaces and configuration to a backup location you control before updating. Chat replay files do not contain the whole home, workspace or tool state.
3. If you have already updated and have no backup, keep the app data intact. Ordinary file managers cannot read another app's private home. Seek a recovery method appropriate to your own device and signing key; do not uninstall as a troubleshooting step.
4. Review the backup privately before manually copying selected files to a trusted remote host. It may contain API keys, tokens and account sessions. Reconfigure credentials deliberately on that host; do not share the home as a public chat file or diagnostic bundle.
5. Check absolute paths, workspace locations, plugin compatibility and file permissions on the destination. Keep the original backup until you have verified the result.

There is no implemented automatic migration, legacy-home export wizard or automatic cleanup. Removing a saved remote connection deletes that connection's saved settings and credentials, not the remote host's files or the preserved old home. Uninstalling the app or clearing Android app data deletes private phone data; use those only after an explicit decision and a verified backup.

For connection setup and current transport limits, see [Remote hosts](03-engine-hosts.md).
