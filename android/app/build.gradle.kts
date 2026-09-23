import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key, read from android/key.properties — a file that is NOT in the
// repository and must never be. It holds the password to the one key that can
// ever publish an update to this app: lose it and the listing cannot be
// updated, leak it and somebody else can publish as the clinic.
//
// Absent (a fresh clone, a CI job that only builds debug), the release build
// falls back to the debug key so `flutter run --release` still works locally.
// It will not produce an uploadable bundle, which is the correct outcome —
// Play rejects a debug-signed bundle outright rather than accepting a build
// nobody can update later.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.tlcmedclinics.tlc_med_clinics"
    // 36, not 35. compileSdk only decides which Android APIs the code can be
    // compiled against — it changes nothing on a patient's phone. The current
    // AndroidX libraries (androidx.core 1.17, androidx.browser 1.9) and the
    // app_links / google_sign_in / url_launcher / webview / shared_preferences
    // plugins refuse to build against anything lower. targetSdk, below, is the
    // one that changes runtime behaviour, and stays where Play requires it.
    compileSdk = 36

    // `ndkVersion` is deliberately not set.
    //
    // The NDK compiles C and C++, and this app contains none. Every package it
    // uses — Firebase, webview_flutter, google_sign_in — ships its Android
    // side as Java/Kotlin, or as .so files already built by somebody else.
    // Naming an NDK version here made Gradle insist on having one: it
    // downloaded a gigabyte of toolchain, the download was interrupted, and
    // every build after that failed on a half-written folder for a tool
    // nothing was going to call.
    //
    // If a package with native code is ever added, Gradle will say so plainly
    // ("No version of NDK matched…"). At that point put the line back:
    //
    //     ndkVersion = flutter.ndkVersion

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

        // minSdk follows Flutter's own default (24 on current Flutter), which is
        // above the 23 that firebase_auth, cloud_firestore and firebase_messaging
        // need. Pinning it lower would fight newer plugins.
        //
        // targetSdk is pinned: Play has required 35 for new apps since
        // 31 August 2025, and that must not depend on which Flutter happens to
        // be on the build machine the day the bundle is made.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Firebase plus Flutter crosses the 64K method limit on older devices.
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Local `flutter run --release` only. See the note above.
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
