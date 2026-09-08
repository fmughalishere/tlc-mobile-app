plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tlcmedclinics.tlc_med_clinics"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Firebase's Android libraries ship class files that need desugaring on
        // older API levels. Turning it on now costs nothing and saves a
        // confusing build failure the day flutter_local_notifications arrives.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tlcmedclinics.tlc_med_clinics"

        // Set explicitly, not inherited from `flutter.minSdkVersion`.
        // firebase_auth requires 23, and inheriting means a Flutter upgrade can
        // silently move it under us.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Firebase plus Flutter crosses the 64K method limit on older devices.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO (before the Play Store upload): a real upload key.
            // Until then, debug keys so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
