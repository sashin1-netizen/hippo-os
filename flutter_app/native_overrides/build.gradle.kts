import com.android.build.api.dsl.ApplicationExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val finalRelease = providers.gradleProperty("HIPPO_FINAL_RELEASE")
    .orElse("false")
    .map { it.equals("true", ignoreCase = true) }

val finalKeystorePath = providers.gradleProperty("HIPPO_KEYSTORE_PATH")
val finalKeystorePassword = providers.gradleProperty("HIPPO_KEYSTORE_PASSWORD")
val finalKeyAlias = providers.gradleProperty("HIPPO_KEY_ALIAS")
val finalKeyPassword = providers.gradleProperty("HIPPO_KEY_PASSWORD")

extensions.configure<ApplicationExtension> {
    namespace = "com.sashin.hippo_os"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("hippoProduction") {
            if (finalRelease.get()) {
                val missing = buildList {
                    if (!finalKeystorePath.isPresent) add("HIPPO_KEYSTORE_PATH")
                    if (!finalKeystorePassword.isPresent) add("HIPPO_KEYSTORE_PASSWORD")
                    if (!finalKeyAlias.isPresent) add("HIPPO_KEY_ALIAS")
                    if (!finalKeyPassword.isPresent) add("HIPPO_KEY_PASSWORD")
                }
                check(missing.isEmpty()) {
                    "Final Hippo OS signing requested but required Gradle properties are missing: ${missing.joinToString(", ")}"
                }
                storeFile = file(finalKeystorePath.get())
                storePassword = finalKeystorePassword.get()
                keyAlias = finalKeyAlias.get()
                keyPassword = finalKeyPassword.get()
            }
        }
    }

    defaultConfig {
        // CI/internal QA stays side-by-side with previous Hippo OS installs. The
        // final personal build switches to the permanent package only when the
        // explicit final-release property is supplied.
        applicationId = if (finalRelease.get()) "com.sashin.hippoos" else "com.sashin.hippoos.preview"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["hippoAppLabel"] = if (finalRelease.get()) "Hippo OS" else "Hippo OS Preview"
    }

    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.gitignore:!.ds_store:!*.scc:<dir>_*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }

    buildTypes {
        release {
            // Preview APKs remain release-optimized and use the temporary debug
            // certificate. Final mode cannot fall back to that certificate.
            signingConfig = if (finalRelease.get()) {
                signingConfigs.getByName("hippoProduction")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.godotengine:godot:4.7.2.stable")
}
