package com.mDev.AdventPraise.church.notification

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mDev.AdventPraise.AdventPraiseApp
import com.mDev.AdventPraise.church.ChurchRemoteAction
import com.mDev.AdventPraise.church.ChurchSession

/**
 * The church remote's buttons (iOS's Live Activity and widget intents): the
 * ongoing notification's Previous / Next / End and the Church Remote
 * widget's verse, Blank and Next hymn. They run [ChurchSession.perform] in
 * the app's process, the same moves as church mode's arrows; the TV, the
 * widget and the notification follow the session.
 *
 * If the app's process had gone (Android stopped it while it was in the
 * background), nothing is presenting any more: the stale notification is
 * taken down and the widget, refreshed as the app starts, offers Present.
 */
class ChurchRemoteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = ChurchRemoteAction.of(intent.getStringExtra(EXTRA_ACTION)) ?: return
        val services = (context.applicationContext as? AdventPraiseApp)?.services ?: return
        val session = services.church
        when (route(session, action)) {
            Route.Perform -> session.perform(action)
            Route.Stale -> {
                ChurchNotifier.cancel(context)
                if (intent.getBooleanExtra(EXTRA_FROM_WIDGET, false)) openApp(context)
            }
        }
    }

    enum class Route { Perform, Stale }

    companion object {
        const val ACTION = "com.mDev.AdventPraise.church.REMOTE"
        const val EXTRA_ACTION = "action"
        const val EXTRA_FROM_WIDGET = "fromWidget"

        /**
         * Whether a button can act: verse buttons need church mode up (or no
         * Pro, which the session answers with the paywall); Next hymn works any
         * time the reader has a hymn.
         */
        fun route(session: ChurchSession, action: ChurchRemoteAction): Route {
            val state = session.current
            if (!state.isPro) return Route.Perform
            if (action == ChurchRemoteAction.NextHymn) return if (state.hymn != null) Route.Perform else Route.Stale
            return if (state.isActive) Route.Perform else Route.Stale
        }

        fun intent(context: Context, action: ChurchRemoteAction, fromWidget: Boolean = false): Intent =
            Intent(context, ChurchRemoteReceiver::class.java)
                .setAction("$ACTION.${action.key}")
                .putExtra(EXTRA_ACTION, action.key)
                .putExtra(EXTRA_FROM_WIDGET, fromWidget)

        fun pendingIntent(context: Context, action: ChurchRemoteAction): PendingIntent =
            PendingIntent.getBroadcast(context, action.ordinal, intent(context, action),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        /** Best effort: Android may not let a widget's broadcast bring the app up; the widget then offers Present. */
        private fun openApp(context: Context) {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
            runCatching { context.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        }
    }
}
