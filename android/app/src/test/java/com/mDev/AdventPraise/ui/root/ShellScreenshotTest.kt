package com.mDev.AdventPraise.ui.root

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.ComponentGallery
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * JVM screenshots of the shell: the launch frame and the design-system gallery,
 * light and dark. `./gradlew recordRoborazziDebug` writes them to
 * app/src/test/screenshots; `verifyRoborazziDebug` compares.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi")
class ShellScreenshotTest {
    @get:Rule val compose = createComposeRule()

    @Test fun splashLight() {
        compose.setContent { SplashFrame(dark = false) }
        compose.onRoot().captureRoboImage("src/test/screenshots/splash_light.png")
    }

    @Test fun splashDark() {
        compose.setContent { SplashFrame(dark = true) }
        compose.onRoot().captureRoboImage("src/test/screenshots/splash_dark.png")
    }

    @Test @Config(qualifiers = "w411dp-h2200dp-xxhdpi")
    fun galleryLight() {
        compose.setContent { ComponentGallery(ReadingSurface.Paper, scrolls = false) }
        compose.onRoot().captureRoboImage("src/test/screenshots/gallery_paper.png")
    }

    @Test @Config(qualifiers = "w411dp-h2200dp-xxhdpi")
    fun galleryDark() {
        compose.setContent { ComponentGallery(ReadingSurface.Black, scrolls = false) }
        compose.onRoot().captureRoboImage("src/test/screenshots/gallery_black.png")
    }

    @Test @Config(qualifiers = "w411dp-h2200dp-xxhdpi")
    fun gallerySepia() {
        compose.setContent { ComponentGallery(ReadingSurface.Sepia, scrolls = false) }
        compose.onRoot().captureRoboImage("src/test/screenshots/gallery_sepia.png")
    }
}
