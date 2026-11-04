plugins { id("com.android.application") }

android {
    namespace = "com.stockgo.nativeapp"
    compileSdk = 36
    defaultConfig {
        // Identidad distinta: no reemplaza ni borra los datos del APK Flutter.
        applicationId = "com.stockgo.nativeapp"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "2.0.0-kotlin"
    }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        val keyPath = System.getenv("STOCKGO_KEYSTORE_PATH")
        val secret = System.getenv("STOCKGO_KEYSTORE_PASSWORD")
        if (!keyPath.isNullOrBlank() && !secret.isNullOrBlank()) {
            create("stockgo") {
                storeFile = file(keyPath)
                storePassword = secret
                keyAlias = "stockgo"
                keyPassword = secret
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("stockgo")
        }
    }
    lint { abortOnError = true }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.activity:activity-ktx:1.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
