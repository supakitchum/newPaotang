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
val customerFlutterApplicationId = propertyOrEnv("CUSTOMER_FLUTTER_APPLICATION_ID")
val customerFlutterAppLabel = propertyOrEnv("CUSTOMER_FLUTTER_APP_LABEL")
val customerFlutterAuthCallbackScheme =
    propertyOrEnv("CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME")
val customerFlutterAuthCallbackHost =
    propertyOrEnv("CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { !it.isNullOrBlank() }
val allowDebugReleaseSigning = propertyOrEnv("CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING")
    ?.lowercase()
    ?.let { it == "1" || it == "true" || it == "yes" }
    ?: false
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.lowercase().contains("release")
}

fun requireReleaseValue(name: String, value: String?) {
    if (!releaseTaskRequested || allowDebugReleaseSigning || !value.isNullOrBlank()) {
        return
    }

    throw org.gradle.api.GradleException(
        "Partner release config is required for customer_flutter release builds. " +
            "Set $name. For local smoke builds only, set " +
            "CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true."
    )
}

android {
    namespace = "com.newpaotang.customer_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = customerFlutterApplicationId
            ?: "com.newpaotang.customer_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] =
            customerFlutterAppLabel ?: "NewPaotang"
        manifestPlaceholders["authCallbackScheme"] =
            customerFlutterAuthCallbackScheme ?: "newpaotang"
        manifestPlaceholders["authCallbackHost"] =
            customerFlutterAuthCallbackHost ?: "auth.invalid"
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
            requireReleaseValue(
                "CUSTOMER_FLUTTER_APPLICATION_ID",
                customerFlutterApplicationId
            )
            requireReleaseValue("CUSTOMER_FLUTTER_APP_LABEL", customerFlutterAppLabel)
            requireReleaseValue(
                "CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME",
                customerFlutterAuthCallbackScheme
            )
            requireReleaseValue(
                "CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST",
                customerFlutterAuthCallbackHost
            )
            signingConfig = when {
                hasReleaseSigning -> signingConfigs.getByName("release")
                allowDebugReleaseSigning -> signingConfigs.getByName("debug")
                !releaseTaskRequested -> signingConfigs.getByName("debug")
                else -> throw org.gradle.api.GradleException(
                    "Release signing inputs are required for customer_flutter. " +
                        "Set CUSTOMER_FLUTTER_STORE_FILE, CUSTOMER_FLUTTER_STORE_PASSWORD, " +
                        "CUSTOMER_FLUTTER_KEY_ALIAS, and CUSTOMER_FLUTTER_KEY_PASSWORD. " +
                        "For local smoke builds only, set " +
                        "CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true."
                )
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
