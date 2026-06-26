plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun propertyOrEnv(name: String): String? {
    return (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(name)?.takeIf { it.isNotBlank() }
}

val releaseStoreFile = propertyOrEnv("CUSTOMER_FLUTTER_STORE_FILE")
val releaseStorePassword = propertyOrEnv("CUSTOMER_FLUTTER_STORE_PASSWORD")
val releaseKeyAlias = propertyOrEnv("CUSTOMER_FLUTTER_KEY_ALIAS")
val releaseKeyPassword = propertyOrEnv("CUSTOMER_FLUTTER_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "com.newpaotang.customer_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = propertyOrEnv("CUSTOMER_FLUTTER_APPLICATION_ID")
            ?: "com.newpaotang.customer_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] =
            propertyOrEnv("CUSTOMER_FLUTTER_APP_LABEL") ?: "NewPaotang"
        manifestPlaceholders["authCallbackScheme"] =
            propertyOrEnv("CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME") ?: "newpaotang"
        manifestPlaceholders["authCallbackHost"] =
            propertyOrEnv("CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST") ?: "auth.invalid"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
