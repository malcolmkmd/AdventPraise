// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.HymnalSource
import com.mDev.AdventPraise.ui.design.LanguagePicker
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.theme.DS

/**
 * All hymnals, as a sheet (HymnalStorePicker in the hymn list's Hymnals sheet).
 * The reader menu's Translation panel is [TranslationSwitcher]. Every hymnal is
 * free, so a tap switches; the sheet closes once the reader shows it.
 */
@Composable
fun HymnalsSheet(services: AppServices, navigator: AppNavigator) {
    val model = services.reader
    ScreenEffect(AnalyticsScreen.Hymnals)
    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        LanguagePicker(
            hymnals = model.catalogue.map { it.design },
            access = model::access,
            onSelect = { hymnal -> model.select(hymnal, HymnalSource.Sidebar) { navigator.dismiss(Destination.Hymnals) } },
            ownsEverything = true,
            modifier = Modifier.padding(DS.Space.l),
        )
    }
}
