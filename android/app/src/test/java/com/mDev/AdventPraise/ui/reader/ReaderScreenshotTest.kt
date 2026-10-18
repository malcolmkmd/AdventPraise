package com.mDev.AdventPraise.ui.reader

import android.app.Application
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.ReaderMenuPanel
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.AdventDrawer
import com.mDev.AdventPraise.ui.design.AdventDrawerStyle
import com.mDev.AdventPraise.ui.library.HymnListScreen
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.SurfaceGround
import com.mDev.AdventPraise.ui.theme.VesperTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * JVM screenshots of the reader area, light (Paper) and dark (Black), on the
 * shipped hymnals: the reader, the SDA Hymnal's look, the number pad and
 * search in the Lectern, the globe menu open on Translation, the hymn list
 * and About this hymn's root.
 * `./gradlew recordRoborazziDebug --tests '*ReaderScreenshotTest'` records them.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi", application = Application::class)
class ReaderScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun services(surface: ReadingSurface, hymnal: String = "english", number: Int = 30): AppServices {
        val services = AppServices(ApplicationProvider.getApplicationContext())
        services.settings.updateSurface(surface)
        services.reader.start()
        compose.waitUntil(20_000) { services.reader.hymn != null && services.reader.crossReference != null }
        if (hymnal != "english") {
            services.reader.switchHymnal(services.catalogs.hymnal(hymnal)!!)
            compose.waitUntil(20_000) { services.reader.hymnal?.id == hymnal }
        }
        services.reader.open(number, HymnSource.Numpad)
        return services
    }

    private fun shot(name: String, surface: ReadingSurface, services: AppServices, content: @Composable () -> Unit) {
        compose.setContent {
            VesperTheme(surface) {
                CompositionLocalProvider(LocalAppNavigator provides services.navigator) {
                    SurfaceGround(Modifier.fillMaxSize()) { content() }
                }
            }
        }
        compose.mainClock.advanceTimeBy(2_000)
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("src/test/screenshots/reader_${name}_${if (surface.isDark) "dark" else "light"}.png")
    }

    private fun reader(name: String, surface: ReadingSurface, hymnal: String = "english", number: Int = 30, setUp: (AppServices) -> Unit = {}) {
        val services = services(surface, hymnal, number)
        setUp(services)
        shot(name, surface, services) { ReaderScreen(services) }
    }

    // The reader

    @Test fun readerLight() = reader("hymn", ReadingSurface.Paper)
    @Test fun readerDark() = reader("hymn", ReadingSurface.Black)
    @Test fun sdaHymnalLight() = reader("sdah", ReadingSurface.Paper, hymnal = "sdah", number = 368)
    @Test fun sdaHymnalDark() = reader("sdah", ReadingSurface.Black, hymnal = "sdah", number = 368)

    // The Lectern

    @Test fun numberPadLight() = reader("number_pad", ReadingSurface.Paper) { it.reader.openLectern(LecternState.Pad); it.reader.proposeDigits("2"); it.reader.proposeDigits("25") }
    @Test fun numberPadDark() = reader("number_pad", ReadingSurface.Black) { it.reader.openLectern(LecternState.Pad); it.reader.proposeDigits("2"); it.reader.proposeDigits("25") }
    @Test fun searchLight() = reader("search", ReadingSurface.Paper) { it.reader.openLectern(LecternState.Search); it.reader.query = "blessed" }
    @Test fun searchDark() = reader("search", ReadingSurface.Black) { it.reader.openLectern(LecternState.Search); it.reader.query = "blessed" }
    @Test fun trayLight() = reader("tray", ReadingSurface.Paper) { it.reader.openLectern(LecternState.Hymn) }
    @Test fun trayDark() = reader("tray", ReadingSurface.Black) { it.reader.openLectern(LecternState.Hymn) }

    // The globe menu

    @Test fun globeMenuLight() = reader("menu_translation", ReadingSurface.Paper) { it.reader.openMenu(ReaderMenuPanel.Translation) }
    @Test fun globeMenuDark() = reader("menu_translation", ReadingSurface.Black) { it.reader.openMenu(ReaderMenuPanel.Translation) }
    @Test fun textMenuLight() = reader("menu_text", ReadingSurface.Paper) { it.reader.openMenu(ReaderMenuPanel.Text) }
    @Test fun aboutPanelDark() = reader("menu_about", ReadingSurface.Black) { it.reader.openMenu(ReaderMenuPanel.About) }

    // The hymn list and About this hymn

    private fun list(surface: ReadingSurface) {
        val services = services(surface)
        services.reader.toggleFavourite()
        shot("list", surface, services) { HymnListScreen(services) }
    }

    @Test fun listLight() = list(ReadingSurface.Paper)
    @Test fun listDark() = list(ReadingSurface.Black)

    private fun about(surface: ReadingSurface) {
        val services = services(surface, number = 218)
        shot("about_hymn", surface, services) {
            AdventDrawer("About this hymn", onDismissRequest = {}, style = AdventDrawerStyle(showsClose = false)) {
                AboutHymnRoot(services, services.navigator, "reader_menu")
            }
        }
    }

    @Test fun aboutHymnLight() = about(ReadingSurface.Paper)
    @Test fun aboutHymnDark() = about(ReadingSurface.Black)
}
