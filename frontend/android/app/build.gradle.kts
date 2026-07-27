plugins {
    id("com.android.application")
    // FEATURE (push notifications, 2026-07-05): applies the plugin declared
    // in settings.gradle.kts -- this is what actually reads
    // android/app/google-services.json at build time. Build will fail with
    // a clear "File google-services.json is missing" error until that file
    // is added -- see PUSH_NOTIFICATIONS_SETUP.md.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.innercircle.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // FIX (2026-07-27): flutter_local_notifications requires core
        // library desugaring to be enabled -- without this, the build fails
        // at :app:checkDebugAarMetadata with "Dependency
        // ':flutter_local_notifications' requires core library desugaring
        // to be enabled for :app." Needed because that plugin (and some of
        // its transitive deps) uses newer java.time APIs that older Android
        // API levels don't support natively -- desugaring backports them.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.innercircle.frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
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

// FIX (2026-07-27): required by the isCoreLibraryDesugaringEnabled flag
// above -- this is the actual desugaring library being pulled in.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}