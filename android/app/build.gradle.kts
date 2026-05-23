plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.advanced_alarm_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // android_alarm_manager_plus uses java.time.* APIs that require core
        // library desugaring on minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.advanced_alarm_app"
        // android_alarm_manager_plus + flutter_local_notifications need
        // minSdk 24 (Android 7.0); the ringing layer (audioplayers,
        // vibration, wakelock_plus, sensors_plus) only needs 23. Pin
        // explicitly to 24 so Gradle doesn't fall back to Flutter's
        // default 21 on either branch's plugins.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by `isCoreLibraryDesugaringEnabled = true` above. Without this,
    // android_alarm_manager_plus will fail to compile on minSdk < 26.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
