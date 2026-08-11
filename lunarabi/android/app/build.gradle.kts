import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun envOrKeystore(envName: String, propertyName: String): String? =
    providers.environmentVariable(envName).orNull ?: keystoreProperties.getProperty(propertyName)

val configuredDeepLinkHost =
    providers.environmentVariable("LUNARABI_DEEP_LINK_HOST").orNull ?: "app.lunarabi.example"
val releaseStoreFile = envOrKeystore("LUNARABI_ANDROID_STORE_FILE", "storeFile")
val releaseStorePassword = envOrKeystore("LUNARABI_ANDROID_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = envOrKeystore("LUNARABI_ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = envOrKeystore("LUNARABI_ANDROID_KEY_PASSWORD", "keyPassword")

fun isPlaceholderHost(host: String): Boolean {
    val normalized = host.lowercase()
    return normalized.isBlank() ||
        normalized == "localhost" ||
        normalized.endsWith(".localhost") ||
        normalized.endsWith(".example") ||
        normalized.endsWith(".invalid")
}

fun releaseInputErrors(): List<String> {
    val errors = mutableListOf<String>()
    val releaseDeepLinkHost = providers.environmentVariable("LUNARABI_DEEP_LINK_HOST").orNull
    if (releaseDeepLinkHost.isNullOrBlank() ||
        isPlaceholderHost(releaseDeepLinkHost) ||
        releaseDeepLinkHost.contains("://") ||
        releaseDeepLinkHost.contains("/") ||
        releaseDeepLinkHost.contains(":")
    ) {
        errors += "Release deep link host must be set with LUNARABI_DEEP_LINK_HOST and must not be a placeholder."
    }
    if (releaseStoreFile.isNullOrBlank()) {
        errors += "Android release signing missing LUNARABI_ANDROID_STORE_FILE or keystore.properties storeFile."
    }
    if (releaseStorePassword.isNullOrBlank()) {
        errors += "Android release signing missing LUNARABI_ANDROID_STORE_PASSWORD or keystore.properties storePassword."
    }
    if (releaseKeyAlias.isNullOrBlank()) {
        errors += "Android release signing missing LUNARABI_ANDROID_KEY_ALIAS or keystore.properties keyAlias."
    }
    if (releaseKeyPassword.isNullOrBlank()) {
        errors += "Android release signing missing LUNARABI_ANDROID_KEY_PASSWORD or keystore.properties keyPassword."
    }
    return errors
}

android {
    namespace = "com.wandit.lunarabi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wandit.lunarabi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["deepLinkHost"] = configuredDeepLinkHost
    }

    signingConfigs {
        create("release") {
            val storeFilePath = releaseStoreFile
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath)
            }
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Lunarabi Dev")
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            resValue("string", "app_name", "Lunarabi Stg")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Lunarabi")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

tasks.configureEach {
    if (name.lowercase().contains("release")) {
        doFirst {
            val errors = releaseInputErrors()
            if (errors.isNotEmpty()) {
                throw GradleException(errors.joinToString(separator = "\n"))
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
