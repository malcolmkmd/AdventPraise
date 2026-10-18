import java.util.Properties

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use(::load)
}

/** A value from local.properties (never committed), then -P, then the environment. */
fun setting(property: String, env: String): String? =
    localProperties.getProperty(property)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(property).orNull?.takeIf { it.isNotBlank() }
        ?: providers.environmentVariable(env).orNull?.takeIf { it.isNotBlank() }

/** RevenueCat's public Google Play SDK key for Advent Praise: public by design, safe to ship. */
val revenueCatPublicKey = "goog_zHpZXDfruZmXDBETYMkhlxDEpoJ"
val revenueCatKey = setting("revenuecat.androidKey", "REVENUECAT_ANDROID_KEY") ?: revenueCatPublicKey
/** The Google Cast custom web receiver (church mode on a TV). Empty until one is registered. */
val castReceiverAppId = setting("cast.receiverAppId", "CAST_RECEIVER_APP_ID") ?: ""

android {
    namespace = "com.mDev.AdventPraise"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.mDev.AdventPraise"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "7.1"

        // RevenueCat public Google Play SDK key ("goog_…"). REVENUECAT_API_KEY is the
        // first milestone's name for the same value, kept until billing moves over.
        buildConfigField("String", "REVENUECAT_ANDROID_KEY", "\"$revenueCatKey\"")
        buildConfigField("String", "REVENUECAT_API_KEY", "\"$revenueCatKey\"")
        buildConfigField("String", "CAST_RECEIVER_APP_ID", "\"$castReceiverAppId\"")
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
        // Sheet music: sheet-music-manifest.json and the phone / pad / line / sync packs
        // (deflated SVG pages and the sync timings, read by offset from the manifest).
        "../../AdventPraise/Resources/SheetMusic",
    )

    androidResources {
        // MediaPlayer opens MIDI files by file descriptor: they must be stored uncompressed.
        // The sheet music packs are already deflated and are read at offsets, so they are
        // stored as they are too (openFd, no inflating a whole pack to reach one hymn).
        noCompress += listOf("mid", "pack")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        // Robolectric (and Roborazzi's screenshots) need the merged resources and assets.
        unitTests.isIncludeAndroidResources = true
        unitTests.all { it.systemProperty("robolectric.graphicsMode", "NATIVE") }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

// Screenshots: `./gradlew recordRoborazziDebug` writes them, `verifyRoborazziDebug` compares.
roborazzi {
    outputDir.set(file("src/test/screenshots"))
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.foundation)
    implementation(libs.compose.animation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.core.ktx)
    implementation(libs.core.splashscreen)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.process)
    implementation(libs.lifecycle.service)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.navigation.compose)
    implementation(libs.coroutines.android)
    implementation(libs.serialization.json)
    implementation(libs.datastore.preferences)
    // Widgets: Hymn of the Day and Church Remote.
    implementation(libs.glance.appwidget)
    implementation(libs.glance.material3)
    // Church mode on a TV: Google Cast (custom web receiver) and the route picker.
    implementation(libs.cast.framework)
    implementation(libs.mediarouter)
    // Sheet music pages are SVG.
    implementation(libs.androidsvg)
    // The piano: no SoundFont synth is published as a usable Android dependency; the
    // music area renders the .sf2 piano itself (Kotlin sampler + MIDI sequencer on AudioTrack).
    implementation(libs.revenuecat.purchases)
    implementation(libs.posthog.android)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.junit)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
