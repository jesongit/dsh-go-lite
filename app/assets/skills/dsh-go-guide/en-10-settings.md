# Settings

Tap the gear at the bottom of the chat list; hold it to search. In Web mode, use **App settings** from the app menu.

<!-- nav: commonSettings -->
`Settings` · [Open](dshgo://open/settings)

Search settings by name in Chinese or English. The top card shows the selected remote host or that no host is selected, and opens remote-host management. Phone appearance and other app settings remain usable without a connection. Host settings need a selected, connected host and the corresponding API.

## AI and host capabilities

- **Models**: manage the current host's supported providers and defaults; see [Models and providers](02-models.md). Configure official DeepSeek credentials on the host; the old local account card and login are removed.
- **Permissions**: inspect or change the current chat's permissions and defaults offered by the host. Read-only, workspace-write and full-access behavior is enforced by the host. Do not assume the old phone-only automatic-command switch applies to remote chats.
- **Personalization**: available agent presets belong to the host. Personal-instruction files and guide/UI skill installation are not automatically migrated or uploaded from the old phone home; configure those on the host when no remote API exists.
- **Web search**, **Engine parameters** and plugin settings use the current host's available APIs. Disconnected, unsupported or read-only settings cannot be saved.
- **Plugins** and **Images and video**: see [Plugins](08-plugins.md). Direct installation and bridge-backed configuration depend on SSH and host support; DSH Remote does not gain those APIs from a direct network path.

There are no local runtime, local DeepSeek login, phone-storage mount or AI phone-control settings.

## App settings

- **Theme**, **Chat text size**, **Collapse steps when done** and **Pets**: see [Appearance](09-appearance.md) and [Pets](06-pets.md).
- **Interface**: native UI or, for connected SSH hosts, DSH Web; see [Web mode](05-web.md).
- **Language**: system, Chinese or English.
- **Notifications**: enable the alert types you want and allow Android notifications. Remote alerts require the app running and its connection online.
- **Voice input**: select supported recognition; this is separate from the removed local DSH engine.
- **Performance**: rendering, blur, motion and refresh-rate options.
- **Background running** and **Diagnostics**: see [Troubleshooting](11-faq.md).
- **Privacy and sharing**: manage shared links, select configuration to share, and turn anonymous usage statistics on or off. Configuration sharing includes only data the current host interfaces can read or import; skill and personal-instruction files are not guaranteed. Review the preview before sharing. **Upload chat logs to DeepSeek** appears only when the host offers it.
- **Remote host**: manage connections and auto-connect; see [Remote hosts](03-engine-hosts.md).

## Updates and help

**Version** shows the app version and build number. **Check for updates** opens available release notes and download options. After verification, **Install** asks Android to update the app; the app closes during installation. Automatic checking does not download or install without your action; **Skip this version** suppresses that version's automatic prompt.

Compatible signing is required to update in place. A differently signed test build cannot replace your installed app. Do not uninstall or clear app data before verifying an external backup. Updates retain old private local data without running, deleting or uploading it. There is no implemented automatic migration; see [Upgrading and legacy local data](04-legacy-data.md).

Help, community, diagnostics and open-source licenses remain available. AI help requires a connected host; bundled guide assets do not mean the guide was automatically installed on that remote host.
