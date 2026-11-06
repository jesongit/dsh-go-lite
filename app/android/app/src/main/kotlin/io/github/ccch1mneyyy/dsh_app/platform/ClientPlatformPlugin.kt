package io.github.ccch1mneyyy.dsh_app.platform

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Generic Android services for the remote client: MethodChannel `dsh/platform`. */
class ClientPlatformPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methods: MethodChannel
    private lateinit var appContext: android.content.Context
    private var activity: ActivityPluginBinding? = null
    private var pendingStorageResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "dsh/platform").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onDetachedFromActivity()
        methods.setMethodCallHandler(null)
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
        pendingStorageResult?.success(PhoneStorage.status(appContext))
        pendingStorageResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "batteryExempt" -> {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(appContext.packageName))
            }
            "requestBatteryExempt" -> result.success(requestBatteryExempt())
            "backgroundSettings" -> result.success(
                mapOf(
                    "vendor" to VendorSettings.vendorOf(Build.MANUFACTURER, Build.BRAND),
                    "label" to appContext.applicationInfo.loadLabel(appContext.packageManager).toString(),
                ),
            )
            "openBackgroundSettings" -> result.success(openVendorSettings(VendorSettings.Switch.BACKGROUND))
            "openVendorSettings" -> result.success(
                openVendorSettings(VendorSettings.Switch.parse(call.argument<String>("switch")) ?: VendorSettings.Switch.BACKGROUND),
            )
            "networkMetered" -> result.success(networkMetered())
            "openAppDetails" -> result.success(openAppDetails())
            "storageStatus" -> result.success(PhoneStorage.status(appContext))
            "requestStorage" -> requestStorage(result)
            "openAllFilesAccess" -> {
                val intent = PhoneStorage.allFilesAccessIntent(appContext)
                result.success(intent != null && runCatching { appContext.startActivity(intent) }.isSuccess)
            }
            else -> result.notImplemented()
        }
    }

    /** The system's "ignore battery optimizations" dialog, else the closest settings page that opens. */
    private fun requestBatteryExempt(): Boolean {
        val packageUri = Uri.parse("package:${appContext.packageName}")
        val host = activity?.activity
        for (intent in listOf(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri),
        )) {
            val started = runCatching {
                if (host != null) host.startActivity(intent)
                else appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }.isSuccess
            if (started) return true
        }
        return false
    }

    /**
     * The vendor's own page for [switch] when one resolves, else this app's system details page:
     * `vendor`, `details`, or null when neither opened.
     */
    private fun openVendorSettings(switch: VendorSettings.Switch): String? {
        val pm = appContext.packageManager
        val packageName = appContext.packageName
        val host = activity?.activity
        fun launch(intent: Intent): Boolean = runCatching {
            if (host != null) host.startActivity(intent)
            else appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
        val vendor = VendorSettings.vendorOf(Build.MANUFACTURER, Build.BRAND)
        for (page in VendorSettings.pages(vendor, switch)) {
            val cls = page.cls
            val intent = if (cls != null) {
                Intent().setComponent(ComponentName(page.pkg, cls))
            } else {
                Intent(page.action ?: continue).setPackage(page.pkg)
            }
            page.packageExtra?.let { intent.putExtra(it, packageName) }
            page.labelExtra?.let { intent.putExtra(it, appContext.applicationInfo.loadLabel(pm).toString()) }
            val info = runCatching { intent.resolveActivityInfo(pm, 0) }.getOrNull()
            if (info?.exported != true) continue
            if (cls == null) intent.setClassName(info.packageName, info.name)
            if (launch(intent)) return "vendor"
        }
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        return if (launch(details)) "details" else null
    }

    /** Whether the active network is metered (mobile data, a metered hotspot); null when unknown. */
    private fun networkMetered(): Boolean? = runCatching {
        val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        if (cm.activeNetwork == null) null else cm.isActiveNetworkMetered
    }.getOrNull()

    /** Asks for READ/WRITE_EXTERNAL_STORAGE; answers with the resulting status map. */
    private fun requestStorage(result: MethodChannel.Result) {
        if (PhoneStorage.isGranted(appContext)) return result.success(PhoneStorage.status(appContext))
        val host: Activity = activity?.activity ?: return result.error("no_activity", "no foreground activity", null)
        pendingStorageResult?.success(PhoneStorage.status(appContext))
        pendingStorageResult = result
        host.requestPermissions(
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
            STORAGE_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != STORAGE_REQUEST) return false
        pendingStorageResult?.success(PhoneStorage.status(appContext))
        pendingStorageResult = null
        return true
    }

    private fun openAppDetails(): Boolean = runCatching {
        appContext.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${appContext.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }.isSuccess

    companion object {
        private const val STORAGE_REQUEST = 0x5d5
    }
}
