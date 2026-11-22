import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ronalds1979.inclusivebible"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ronalds1979.inclusivebible"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit GenAI Image Description (Gemini Nano) requires Android 8.0 (API 26)+.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val envStoreFile = System.getenv("ANDROID_KEYSTORE_PATH")
            val envStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
            val envKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")

            val storeFilePath = envStoreFile?.takeIf { it.isNotBlank() }
                ?: keystoreProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                val rootResolved = rootProject.file(storeFilePath)
                storeFile = if (rootResolved.exists()) rootResolved else file(storeFilePath)
            }
            storePassword = envStorePassword?.takeIf { it.isNotBlank() }
                ?: keystoreProperties.getProperty("storePassword")
            keyAlias = envKeyAlias?.takeIf { it.isNotBlank() }
                ?: keystoreProperties.getProperty("keyAlias")
            keyPassword = envKeyPassword?.takeIf { it.isNotBlank() }
                ?: keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // ⚡ Bolt: Enable R8 code shrinking and resource shrinking for smaller, faster release APKs
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            val hasEnvSigning = !System.getenv("ANDROID_KEYSTORE_PATH").isNullOrBlank()
            if (hasEnvSigning || keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.mlkit:genai-image-description:1.0.0-beta1")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.google.guava:guava:33.3.1-android")
}
