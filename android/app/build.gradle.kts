plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    val stockGoKeyFile = System.getenv("STOCKGO_KEYSTORE_PATH")
    val stockGoKeyPassword = System.getenv("STOCKGO_KEYSTORE_PASSWORD")
    signingConfigs {
        if (!stockGoKeyFile.isNullOrBlank() && !stockGoKeyPassword.isNullOrBlank()) {
            create("stockgoRelease") {
                storeFile = file(stockGoKeyFile)
                storePassword = stockGoKeyPassword
                keyAlias = "stockgo"
                keyPassword = stockGoKeyPassword
            }
        }
    }
    namespace = "com.example.aplicacion_android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.aplicacion_android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Flutter 3.47 supports Android 7.0 (API 24) and newer.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (stockGoKeyFile.isNullOrBlank() && gradle.startParameter.taskNames.any { it.contains("Release") }) {
                throw GradleException("Compila con scripts/compilar_apk.ps1 para cargar la firma privada de StockGo.")
            }
            signingConfig = signingConfigs.findByName("stockgoRelease")
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
