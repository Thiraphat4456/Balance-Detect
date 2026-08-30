plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.balancedetect.balance_detect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.balancedetect.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Controlled prototype builds use the debug key. Distribution
            // builds must supply a private release keystore.
            signingConfig = signingConfigs.getByName("debug")

            // CameraX/WorkManager and the bundled ML Kit pose detector still
            // discover Android components through reflection. The current R8
            // release pass removes required constructors on this dependency
            // set, causing the app to crash in AndroidX Startup before Flutter
            // is created. Keep shrinking disabled until these dependencies are
            // upgraded or verified keep rules are added and tested on-device.
            isMinifyEnabled = false
            isShrinkResources = false
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
