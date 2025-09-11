import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore for THIS project (driver)
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    require(keystorePropsFile.exists()) {
        "key.properties not found at: ${keystorePropsFile.absolutePath}"
    }
    load(keystorePropsFile.inputStream())
}

android {
    // DRIVER app
    namespace = "com.bbkk.luckygo_pemandu"

    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.bbkk.luckygo_pemandu"
        minSdk = 23
        targetSdk = 35
        versionCode = 4
        versionName = "1.0.3"
    }

    signingConfigs {
        create("release") {
            val ksFile = rootProject.file((keystoreProps["storeFile"] as String).trim())
            require(ksFile.exists()) { "Keystore not found at: ${ksFile.absolutePath}" }
            println("➡ [Driver] Using release keystore: ${ksFile.absolutePath}")

            storeFile = ksFile
            storePassword = (keystoreProps["storePassword"] as String).trim()
            keyAlias = (keystoreProps["keyAlias"] as String).trim()
            keyPassword = (keystoreProps["keyPassword"] as String).trim()
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug { }
    }
}

flutter { source = "../.." }
