package io.github.ccch1mneyyy.dsh_app.platform

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings

/**
 * Access to shared storage for client file operations.
 *
 * With targetSdk 28 the app keeps legacy external storage, so the classic
 * READ/WRITE_EXTERNAL_STORAGE grant is enough; "All files access" is the fallback
 * for devices that don't honour legacy mode.
 */
object PhoneStorage {
    fun isGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) return true
        val write = context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        if (!write) return false
        // Legacy view: the permission really grants file-path access to shared storage.
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Environment.isExternalStorageLegacy()
    }

    fun status(context: Context): Map<String, Any?> = mapOf(
        "granted" to isGranted(context),
        "permission" to (context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED),
        "legacy" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Environment.isExternalStorageLegacy()),
        "hostPath" to Environment.getExternalStorageDirectory().absolutePath,
    )

    /** Opens the system "All files access" page for this app (Android 11+). */
    fun allFilesAccessIntent(context: Context): Intent? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
