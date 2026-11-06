package io.github.ccch1mneyyy.dsh_app.diagnostics

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.ccch1mneyyy.dsh_app.voice.VoiceDiagnostics
import io.github.ccch1mneyyy.dsh_app.update.ApkInstaller
import java.io.File
import kotlin.concurrent.thread

/**
 * Facts for the diagnostics bundle that only Android knows: MethodChannel `dsh/diagnostics`.
 *
 * - `info` → `{app: {versionName, versionCode, abi}, device: {manufacturer, brand, model,
 *   android, sdkInt, abis, memoryMb, freeStorageMb, display: {widthPx, heightPx, density,
 *   densityDpi, fontScale}}, voice: Map}`.
 *
 * Nothing here reads user content, keys or tokens.
 */
class DiagnosticsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var methods: MethodChannel? = null
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        methods = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> background(result) { mapOf("app" to app(), "device" to device(), "voice" to VoiceDiagnostics.snapshot(context)) }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        thread(name = "dsh-diagnostics") {
            val outcome = runCatching(work)
            main.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("failed", it.message, null) },
                )
            }
        }
    }

    private fun app(): Map<String, Any?> {
        val pkg = runCatching { context.packageManager.getPackageInfo(context.packageName, 0) }.getOrNull()
        return mapOf(
            "versionName" to pkg?.versionName,
            "versionCode" to pkg?.let { ApkInstaller.versionCodeOf(it) },
            // .../lib/arm64 or .../lib/x86_64: the ABI this APK was built for.
            "abi" to context.applicationInfo.nativeLibraryDir?.let { File(it).name },
        )
    }

    private fun device(): Map<String, Any?> {
        val memory = ActivityManager.MemoryInfo()
        runCatching { (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory) }
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "android" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "memoryMb" to memory.totalMem / MB,
            "freeStorageMb" to context.filesDir.usableSpace / MB,
            // What dp and the pet's k are computed from (pet/PetPack.kt): a size that looks wrong
            // in the overlay or the app is read against these.
            "display" to display(),
        )
    }

    private fun display(): Map<String, Any?> {
        val metrics = context.resources.displayMetrics
        return mapOf(
            "widthPx" to metrics.widthPixels,
            "heightPx" to metrics.heightPixels,
            "density" to metrics.density,
            "densityDpi" to metrics.densityDpi,
            "fontScale" to context.resources.configuration.fontScale,
        )
    }

    companion object {
        const val CHANNEL = "dsh/diagnostics"
        private const val MB = 1024L * 1024L

    }
}
