// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.ui.root.AppNavigator

/** What the extras pages do beyond their own screen (the `Extras` singleton on iOS). */
object ExtrasActions {
    enum class Queue { ServicePlan, Collection }

    /**
     * Runs [numbers] in church mode, in order, stopping after the last
     * (Extras.startChurchMode). [name] heads the list in church mode's number pad.
     * More (or the drawer) closes first; church mode then opens on the first hymn.
     */
    fun startChurchMode(services: AppServices, navigator: AppNavigator, numbers: List<Int>, name: String, queue: Queue) {
        val hymnal = services.reader.hymnal ?: return
        val source = if (queue == Queue.ServicePlan) HymnSource.ServicePlan else HymnSource.Collection
        val target = services.queue.play(numbers, name, source, hymnal) ?: return
        services.reader.show(target, source.key)
        when (queue) {
            Queue.ServicePlan -> {
                Analytics.track(AnalyticsEvent.ServicePlanStarted(numbers.size))
                navigator.openChurchMode(ChurchModeSource.ServicePlan.key)
            }
            Queue.Collection -> {
                Analytics.track(AnalyticsEvent.CollectionStarted(numbers.size))
                navigator.openChurchMode(ChurchModeSource.Collection.key)
            }
        }
    }
}

/** Sends the screen once when it appears (`.analyticsScreen(_:)`). */
@Composable
fun AnalyticsScreenEffect(screen: AnalyticsScreen) {
    LaunchedEffect(screen) { Analytics.screen(screen) }
}
