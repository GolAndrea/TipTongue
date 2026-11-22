import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties().apply {
    val file = rootDir.resolve("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.tiponmytongue.tip_on_my_tongue"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tiponmytongue.tip_on_my_tongue"
        // Meta Wearables DAT v1.0.1 requires minSdk 31+ (Android 12+)
        minSdk = 31
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Optional Meta Wearables Developer Center credentials (empty works in Developer Mode)
        manifestPlaceholders["mwdat_application_id"] =
            localProps.getProperty("mwdat_application_id", "")
        manifestPlaceholders["mwdat_client_token"] =
            localProps.getProperty("mwdat_client_token", "")
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Official Meta Wearables Device Access Toolkit v1.0.1 (Maven Central)
    // NOTE: mwdat-camera is intentionally omitted so camera & privacy LED stay 100% OFF.
    implementation("com.meta.wearable:mwdat-core:1.0.1")
    implementation("com.meta.wearable:mwdat-display:1.0.1")
    implementation("com.meta.wearable:mwdat-mockdevice:1.0.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}

flutter {
    source = "../.."
}
