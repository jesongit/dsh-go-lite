import 'package:flutter/services.dart';

/// Android storage access used for file save and preview.
class StorageAccess {
  const StorageAccess({
    required this.granted,
    required this.permission,
    required this.legacy,
    this.hostPath = '/sdcard',
  });

  factory StorageAccess.fromMap(Map<Object?, Object?> map) => StorageAccess(
    granted: map['granted'] == true,
    permission: map['permission'] == true,
    legacy: map['legacy'] == true,
    hostPath: map['hostPath'] as String? ?? '/sdcard',
  );

  final bool granted;

  /// The runtime permission is granted (may still need "All files access" when not [legacy]).
  final bool permission;
  final bool legacy;
  final String hostPath;
}

/// See [ClientPlatform.backgroundSettings].
class BackgroundSettingsInfo {
  const BackgroundSettingsInfo({this.vendor, this.label});
  final String? vendor;
  final String? label;
}

/// Shared Android client services, independent of any DSH engine.
class ClientPlatform {
  ClientPlatform({MethodChannel? methods}) : _methods = methods ?? const MethodChannel('dsh/platform');
  final MethodChannel _methods;
  Future<StorageAccess> storageStatus() async =>
      StorageAccess.fromMap(await _methods.invokeMapMethod<Object?, Object?>('storageStatus') ?? const {});

  /// Shows the system storage permission prompt; resolves with the resulting access.
  Future<StorageAccess> requestStorage() async =>
      StorageAccess.fromMap(await _methods.invokeMapMethod<Object?, Object?>('requestStorage') ?? const {});

  /// Opens Android's "All files access" page for this app (fallback when legacy access is off).
  Future<bool> openAllFilesAccess() async => await _methods.invokeMethod<bool>('openAllFilesAccess') ?? false;

  /// Whether Android leaves DSH out of battery optimization; null without the native side.
  Future<bool?> batteryExempt() async {
    try {
      return await _methods.invokeMethod<bool>('batteryExempt');
    } on MissingPluginException {
      return null;
    }
  }

  /// Asks for the exemption (the system dialog, else the closest settings page); false if none opened.
  Future<bool?> requestBatteryExempt() async {
    try {
      return await _methods.invokeMethod<bool>('requestBatteryExempt');
    } on MissingPluginException {
      return null;
    }
  }

  /// The phone maker (`vivo`, `xiaomi`, `huawei`, `honor`, `oppo`, `samsung`, null for the
  /// rest) and the app's name as the system settings list it; null without the native side.
  Future<BackgroundSettingsInfo?> backgroundSettings() async {
    try {
      final map = await _methods.invokeMapMethod<Object?, Object?>('backgroundSettings');
      if (map == null) return null;
      return BackgroundSettingsInfo(vendor: map['vendor'] as String?, label: map['label'] as String?);
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the maker's background-running page, else the app's system details page:
  /// `vendor`, `details`, or null when nothing opened.
  Future<String?> openBackgroundSettings() async {
    try {
      return await _methods.invokeMethod<String>('openBackgroundSettings');
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the maker's page for one of its own switches ([vendorSwitch]: `background`,
  /// `autostart`, `popup`), else the app's system details page: `vendor`, `details`, or null
  /// when nothing opened (also without the native side).
  Future<String?> openVendorSettings(String vendorSwitch) async {
    try {
      return await _methods.invokeMethod<String>('openVendorSettings', {'switch': vendorSwitch});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Whether the active network is metered (mobile data); null when unknown or without the
  /// native side.
  Future<bool?> networkMetered() async {
    try {
      return await _methods.invokeMethod<bool>('networkMetered');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> openAppDetails() async => await _methods.invokeMethod<bool>('openAppDetails') ?? false;
}
