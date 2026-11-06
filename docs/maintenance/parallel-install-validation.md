# 并行验证包：签名不一致时保留旧安装

2026-11-06：设备已有 `io.github.ccch1mneyyy.dsh_app`，版本 `1.0.11 (11051428)`。当前主机没有原 keystore 或发布签名配置，标准 Debug 签名验证包不能覆盖旧应用。用户选择生成独立包名的并行验证版。

## 隔离方式

- 并行包名：`io.github.ccch1mneyyy.dsh_app.remote_test`。
- 中文桌面名称：`DSH Go 远程测试`；默认英文名称：`DSH Go Remote Test`。
- 仅在 Gradle 属性 `dshParallelInstall=true` 时启用；不改变普通构建的包名、源代码 namespace、签名策略、SDK 和依赖。
- manifest 与资源使用单独的 parallel overlay；桌面长按快捷方式指向并行包，FileProvider authorities 根据实际 applicationId 独立生成。
- 两个应用的数据、主机配置和授权相互独立。并行版不会接管、导入或上传旧安装的数据。首次使用需重新配置远程主机和系统权限。
- 两个应用都可处理现有 `dshgo` 链接，系统可能显示应用选择器；验证时选择远程测试版。

## 构建

在仓库根目录、已配置 Flutter/JDK/Android SDK 的 PowerShell 中：

```powershell
python tooling/build_apk.py -f arm64 --keep-daemon -- --android-project-arg=dshParallelInstall=true
```

该开关仅作用于本次 Gradle 构建。普通构建不传此参数，或显式传 `dshParallelInstall=false`。本次曾发现环境变量形式未生效，已改用上述显式项目参数，并以 APK 内的实际包名作为交付检查条件。标准脚本仍使用原输出名；本次构建前备份标准 APK 和 SHA-1 文件，生成后把并行包单独保存，并恢复标准产物、核对原始 SHA-256，避免旧下载链接被替换成另一包名。

并行交付路径：`app/build/parallel-apk/app-arm64-remote-test-release.apk`。

最终版本：**1.0.11+11061755**；58,795,764 字节；arm64-v8a。SHA-256：`7d1422a94ccca008b1de22a408ebdb3cbecf0ffce60e10e26add926c7f2d181d`。

本次修正后实际命令为：

```powershell
python tooling/build_apk.py -f arm64 -n 11061755 --keep-daemon -- --android-project-arg=dshParallelInstall=true
```

最终成品已验证：

- `aapt2 dump badging` 包名为 `io.github.ccch1mneyyy.dsh_app.remote_test`，英文/中文名称正确，minSdk 26 / targetSdk 28。
- 所有 4 个 provider authorities 均以并行包名开头；两个静态快捷方式均指向并行包，Activity 类仍使用既有 namespace。
- `apksigner verify --verbose --print-certs` 通过 v2 签名验证，签名为 Android Debug；`zipalign -c -P 16 4` 通过。
- 无 rootfs、PRoot、Node 或旧本地认证载荷。
- 标准 arm64 APK 恢复后的 SHA-256 仍为 `a32daf36571a4035536fd1565b7783487d268a28ca9bc5c1cfd3011795571d26`，原下载路径未替换成并行包。
- `git diff --check` 通过；依赖锁及共享 Dart 包没有改动，没有暂存或提交。

最终包检查结果在 `app/build/parallel-validation/inspection.json`。末次 ADB 查询设备已断开，因此没有执行安装或启动验证；实际手机安装结果仍待用户连接设备后确认。

## 安装

```powershell
adb install .\app-arm64-remote-test-release.apk
```

此命令安装独立应用，不覆盖原包名。没有执行卸载、清除数据、导出旧数据或自动凭据迁移。签名不一致的原包名覆盖更新仍须原签名密钥，或兼容的合法签名 lineage。
