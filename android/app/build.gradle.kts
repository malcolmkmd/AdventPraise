import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use(::load)
}

/** A value from -P, the environment, or local.properties (never committed). */
fun secret(property: String, env: String): String =
    providers.gradleProperty(property).orNull
        ?: providers.environmentVariable(env).orNull
        ?: localProperties.getProperty(property)
        ?: ""

android {
    namespace = "com.mDev.AdventPraise"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.mDev.AdventPraise"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "7.1"

        // RevenueCat public Google Play SDK key ("goog_…"); empty turns purchases off.
        buildConfigField("String", "REVENUECAT_API_KEY", "\"${secret("revenuecat.androidKey", "REVENUECAT_ANDROID_KEY")}\"")
        // Debug builds log analytics and send nothing, unless built with -Panalytics.debugSend=true.
        buildConfigField("boolean", "ANALYTICS_DEBUG_SEND", (providers.gradleProperty("analytics.debugSend").orNull == "true").toString())
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // iOS is the source of truth: the hymnals (hymnals.json and one <key>.json
    // per translation), the MIDI accompaniment and the shared legal text are
    // read straight from the iOS app's folders, not copied. They land flat in the APK's assets,
    // as they do in the iOS bundle.
    sourceSets["main"].assets.srcDirs(
        "../../AdventPraise/Resources/Hymnals",
        "../../AdventPraise/Resources/Midi",
        // sdah_tunes.json: which SDA Hymnal hymns share a Christ In Song tune (and so its MIDI).
        "../../AdventPraise/Resources/Extras",
        // Shared legal text (legal/hymn-content-terms.md), shown in the Terms of Use.
        "../../legal",
    )

    androidResources {
        // MediaPlayer opens MIDI files by file descriptor: they must be stored uncompressed.
        noCompress += listOf("mid")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.process)
    implementation(libs.coroutines.android)
    implementation(libs.revenuecat.purchases)
    implementation(libs.posthog.android)
    debugImplementation(libs.compose.ui.tooling)
    testImplementation(libs.junit)
}
