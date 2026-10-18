package com.mDev.AdventPraise.church.notification

import android.Manifest
import android.annotation.SuppressLint
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.R
import com.mDev.AdventPraise.church.ChurchActivityState
import com.mDev.AdventPraise.church.ChurchRemoteAction
import com.mDev.AdventPraise.church.ChurchState
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach

/**
 * Church mode's Live Activity on Android: an ongoing notification while
 * presenting with Pro (ChurchLiveActivity). It follows the hymn and verse,
 * "Verse 2 of 4 · On TV", and carries iOS's Previous / Next / End buttons,
 * which act on [com.mDev.AdventPraise.church.ChurchSession] directly
 * ([ChurchRemoteReceiver]), so they work from the lock screen and the
 * shade; the TV follows the same state. End asks church mode to close.
 *
 * No foreground service: church mode keeps the screen on while it presents,
 * so the app is in the foreground whenever there is something to present,
 * and a service can't keep the TV up anyway (the Presentation belongs to the
 * activity). If the process dies, a button press finds nothing presenting
 * and takes the stale notification down.
 */
object ChurchNotifier {
    const val CHANNEL_ID = "church_mode"
    const val NOTIFICATION_ID = 7_001
    private const val PREFS = "church"
    private const val ASKED = "church.notificationsAsked"

    /** The brass of the Live Activity's Next button and hymn number. */
    private const val BRASS = 0xFFD6AD61.toInt()

    fun start(app: Application, services: AppServices) {
        createChannel(app)
        services.church.state
            .map(::content)
            .distinctUntilChanged()
            .onEach { content -> if (content == null) cancel(app) else post(app, content) }
            .launchIn(services.scope)
    }

    /** What the notification shows: only while church mode is up, with Pro (iOS starts the activity then). */
    fun content(state: ChurchState): ChurchActivityState? = if (state.isActive && state.isPro) state.activityState else null

    /** The permission is asked once, the first time church mode opens with Pro (Android 13+). */
    fun shouldAsk(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return false
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return false
        return !context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ASKED, false)
    }

    fun markAsked(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ASKED, true).apply()

    fun cancel(context: Context) = NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val channel = NotificationChannel(CHANNEL_ID, "Church mode", NotificationManager.IMPORTANCE_LOW).apply {
            description = "The hymn and verse you're presenting, with Previous, Next and End."
            setShowBadge(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    /** The notification's text, as the Lock Screen view's. */
    fun title(state: ChurchActivityState): String = "${state.hymnNumber} · ${state.title}"
    fun text(state: ChurchActivityState): String = if (state.isOnTV) "${state.position} · On TV" else state.position

    @SuppressLint("MissingPermission")
    private fun post(context: Context, state: ChurchActivityState) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            ?.let { PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT) }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.sda_logo)
            .setColor(BRASS)
            .setContentTitle(title(state))
            .setContentText(text(state))
            .setSubText(state.hymnal)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(R.drawable.ic_church_previous, "Previous", ChurchRemoteReceiver.pendingIntent(context, ChurchRemoteAction.Previous))
            .addAction(R.drawable.ic_church_next, "Next", ChurchRemoteReceiver.pendingIntent(context, ChurchRemoteAction.Next))
            .addAction(R.drawable.ic_church_end, "End", ChurchRemoteReceiver.pendingIntent(context, ChurchRemoteAction.End))
            .build()
        runCatching { manager.notify(NOTIFICATION_ID, notification) }
    }
}
