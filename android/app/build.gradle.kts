import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: prefer android/key.properties (local keystore) or the KEYSTORE_PATH /
// KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD environment variables (CI).
// Falls back to the debug key so local dev builds keep working.
val keystoreProperties = Properties().apply {
    val keyProps = rootProject.file("key.properties")
    if (keyProps.exists()) FileInputStream(keyProps).use { load(it) }
}
val releaseStoreFilePath =
    keystoreProperties.getProperty("storeFile") ?: System.getenv("KEYSTORE_PATH")
val releaseStoreFile =
    releaseStoreFilePath?.takeIf { it.isNotBlank() }?.let { file(it) }

android {
    namespace = "com.mobili.app.mobili"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mobili.app.mobili"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFile != null) {
                storeFile = releaseStoreFile
                storePassword =
                    keystoreProperties.getProperty("storePassword")
                        ?: System.getenv("KEYSTORE_PASSWORD")
                keyAlias =
                    keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS")
                keyPassword =
                    keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "MoBili: release keystore not configured (android/key.properties or KEYSTORE_PATH env). " +
                        "Falling back to debug signing; this artifact cannot be installed over a previous release."
                )
                signingConfigs.getByName("debug")
            }
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
