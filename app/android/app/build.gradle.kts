import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Opt-in validation install; the default package and signing contracts stay unchanged.
val parallelInstall = providers.gradleProperty("dshParallelInstall").map { it.toBooleanStrict() }.getOrElse(false)

val keyProps = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

// Debug builds use the release key only when it is all there; they are never the build
// that should stop over a half-filled key.properties.
// A password may be nothing but spaces; a path or an alias may not.
val hasWholeReleaseKey = listOf("storeFile", "keyAlias").all { !keyProps.getProperty(it).isNullOrBlank() } &&
    listOf("storePassword", "keyPassword").all { !keyProps.getProperty(it).isNullOrEmpty() } &&
    file(keyProps.getProperty("storeFile")).exists()

// versionCode is the build minute, same encoding as tooling/build_number.py:
// (year - 2026) * 10^8 + MMDDhhmm at UTC+8. tooling/build-apk.sh passes it as
// --build-number; this covers builds that skip the script (flutter run, the
// IDE), where pubspec's `+1` placeholder would be a downgrade and make
// `flutter run` uninstall the installed app, data included.
fun buildMinuteVersionCode(): Int {
    val t = OffsetDateTime.now(ZoneOffset.ofHours(8))
    return (t.year - 2026) * 100_000_000 + t.monthValue * 1_000_000 + t.dayOfMonth * 10_000 + t.hour * 100 + t.minute
}

android {
    namespace = "io.github.ccch1mneyyy.dsh_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (parallelInstall) "io.github.ccch1mneyyy.dsh_app.remote_test" else "io.github.ccch1mneyyy.dsh_app"
        // Keep the supported Android versions unchanged in this client conversion.
        minSdk = 26
        // A target SDK migration is separate from removing the local engine.
        targetSdk = 28
        versionCode = flutter.versionCode.takeIf { it > 1 } ?: buildMinuteVersionCode()
        versionName = flutter.versionName
    }

    flavorDimensions += "abi"
    productFlavors {
        create("arm64") {
            dimension = "abi"
            ndk { abiFilters += "arm64-v8a" }
        }
        create("x64") {
            dimension = "abi"
            ndk { abiFilters += "x86_64" }
        }
    }

    if (parallelInstall) {
        for (flavor in listOf("arm64", "x64")) {
            sourceSets.getByName(flavor).apply {
                manifest.srcFile("src/parallel/AndroidManifest.xml")
                res.srcDir("src/parallel/res")
            }
        }
    }

    lint {
        // targetSdk 28 is deliberate (see docs/architecture.md); not a Play build.
        disable += "ExpiredTargetSdkVersion"
    }

    signingConfigs {
        if (!keyProps.isEmpty) {
            create("release") {
                storeFile = keyProps.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                // All three schemes: AGP drops v1 for minSdk 24+, but some installers and
                // security scanners on Chinese ROMs still read the JAR signature.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        debug {
            // tooling/dev-run.sh installs debug over the release build on a phone, data
            // kept: Android only allows that with the same key.
            if (hasWholeReleaseKey) signingConfig = signingConfigs.getByName("release")
        }
        release {
            // Use the release key when configured; local builds without key.properties fall back to debug.
            signingConfig = signingConfigs.getByName(if (keyProps.isEmpty) "debug" else "release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")

    implementation("androidx.webkit:webkit:1.15.0") // Apache-2.0: web islands' force dark (webview_flutter's own version)
}
