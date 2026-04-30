import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val mStoreFile: File = file("keystore.jks")
val mStorePassword: String? = localProperties.getProperty("storePassword")
val mKeyAlias: String? = localProperties.getProperty("keyAlias")
val mKeyPassword: String? = localProperties.getProperty("keyPassword")
val isRelease = mStoreFile.exists()
        && mStorePassword != null
        && mKeyAlias != null
        && mKeyPassword != null

android {
    namespace = "app.dropweb"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.dropweb"
        // hardcoded — flutter_secure_storage 10.x requires minSdk=24 (Android 7.0+),
        // and the core module already required ≥23. Bumped from 23 to 24 together
        // with the secure-storage migration in 2712935. Older Flutter SDKs in CI
        // default to 21; leaving this as `flutter.minSdkVersion` is NOT safe here.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isRelease) {
            create("release") {
                storeFile = mStoreFile
                storePassword = mStorePassword
                keyAlias = mKeyAlias
                keyPassword = mKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            // Must be TRUE to extract libparazitx-relay.so onto disk, where
            // Android 10+ SELinux still allows exec() for our own package.
            // With useLegacyPackaging=false the .so stays inside the APK zip
            // and ProcessBuilder.start() fails with EACCES.
            //
            // 16KB page alignment (required by Google Play for Android 15+)
            // is preserved by building each .so with `-Wl,-z,max-page-size=16384`
            // at the NDK/Go level, not by the packaging flag. The mihomo/clash
            // core libs already ship aligned; the bundled relay binary is
            // verified aligned.
            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false

            signingConfig = if (isRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// Force androidx.datastore 1.1.7 — 1.2.0 ships a libdatastore_shared_counter.so
// that is NOT 16KB-aligned and causes Google Play rejection.
// See: https://github.com/flutter/flutter/issues/182898
// TODO: remove once datastore 1.3.0 (with proper 16KB alignment) is stable.
configurations.all {
    resolutionStrategy {
        force("androidx.datastore:datastore:1.1.7")
        force("androidx.datastore:datastore-android:1.1.7")
        force("androidx.datastore:datastore-preferences:1.1.7")
        force("androidx.datastore:datastore-preferences-android:1.1.7")
    }
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
    implementation(project(":core"))
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("com.android.tools.smali:smali-dexlib2:3.0.9") {
        exclude(group = "com.google.guava", module = "guava")
    }
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
