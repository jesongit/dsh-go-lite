# Reload plugin code on a remote host

[中文](../local-development.md)

After editing the code remote DSH actually loads, run the plugin's build and restart `dsh web` using that host's development workflow. The old phone-local “Restart engine to reload” entry is removed. The app does not synchronize plugin directories or restart remote processes for you. Confirm that running tasks may be interrupted before restarting.

- Local paths on SSH and DSH Remote belong to the remote host. Directory installations may link sources or copy them; identify the actual loaded files first.
- After changing `lib/`, update the loaded entry point. Removing/reinstalling or disabling/enabling does not guarantee invalidation of JavaScript module caches.
- The bridge rereads `dshGo` declarations in `package.json` by modification time. Declaration refresh is separate from source-code reload.
- Automatic application of `cordis.patch.yml` depends on the host's HMR configuration. The app has no verified remote plugin-level HMR operation and does not modify `hmr.config.root` for you.
- After reconnecting, check plugin details, loading/parse diagnostics and host logs. Requesting a restart does not prove the plugin loaded successfully.

See [Hosts](hosts.md) for installation and transport limits.
