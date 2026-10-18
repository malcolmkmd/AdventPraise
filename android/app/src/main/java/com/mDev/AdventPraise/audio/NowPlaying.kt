// OWNER: music
package com.mDev.AdventPraise.audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState as SessionState
import android.os.Build
import android.os.IBinder
import com.mDev.AdventPraise.AdventPraiseApp
import com.mDev.AdventPraise.MainActivity
import com.mDev.AdventPraise.R
import kotlin.math.roundToLong

/**
 * The lock screen and headphone controls (MPNowPlayingInfoCenter and
 * MPRemoteCommandCenter on iOS): a [MediaSession] that says which hymn is
 * up ("12. Title", the hymnal, "Verse 2 of 4"), how far through at the
 * chosen tempo, and takes play, pause, toggle, previous (restart), next
 * (the next hymn) and seek, all through the [AccompanimentPlayer] so the
 * free-play gate applies. While the accompaniment is active a media
 * notification carries the controls, posted by [AccompanimentService] in the
 * foreground so playback carries on with the screen off.
 */
class NowPlaying(private val context: Context, private val player: AccompanimentPlayer) {
    private var session: MediaSession? = null
    private var shown: Boolean = false
    private var lastKey: Any? = null

    init {
        player.onChange = ::update
    }

    private fun session(): MediaSession = session ?: MediaSession(context, "Advent Praise accompaniment").also { s ->
        s.setCallback(object : MediaSession.Callback() {
            override fun onPlay() = player.play()
            override fun onPause() = player.pause()
            override fun onSkipToPrevious() = player.restart()
            override fun onSkipToNext() { player.onNextTrack?.invoke() }
            // The lock screen speaks wall-clock time; the player, performance time.
            override fun onSeekTo(pos: Long) = player.seek(pos / 1000.0 * player.tempo.rate)
            override fun onStop() = player.stop()
        })
        session = s
    }

    /** Mirrors the player; called on every change. */
    fun update() {
        val hymn = player.hymn
        if (!player.isActive || hymn == null) {
            clear()
            return
        }
        val s = session()
        val passes = player.passCount
        val verse = player.position?.let { if (passes > 0) "Verse ${it.pass} of $passes" else "" }.orEmpty()
        val title = "${hymn.number}. ${hymn.title}"
        val artist = player.hymnal?.name.orEmpty()
        val durationMs = (player.displayDuration * 1000).roundToLong()
        val key = listOf(title, artist, verse, durationMs)
        if (key != lastKey) {
            lastKey = key
            s.setMetadata(MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, verse)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
                .build())
        }
        val actions = SessionState.ACTION_PLAY or SessionState.ACTION_PAUSE or SessionState.ACTION_PLAY_PAUSE or
            SessionState.ACTION_SKIP_TO_PREVIOUS or SessionState.ACTION_SEEK_TO or
            (if (player.onNextTrack != null) SessionState.ACTION_SKIP_TO_NEXT else 0L)
        s.setPlaybackState(SessionState.Builder()
            .setActions(actions)
            .setState(
                if (player.isPlaying) SessionState.STATE_PLAYING else SessionState.STATE_PAUSED,
                (player.displayElapsed * 1000).roundToLong(),
                if (player.isPlaying) 1f else 0f,
            )
            .build())
        if (!s.isActive) s.isActive = true
        post(notification(s, title, artist, verse))
    }

    private fun clear() {
        lastKey = null
        session?.let { it.isActive = false }
        current = null
        if (shown) {
            shown = false
            AccompanimentService.running?.finish()
            runCatching { manager().cancel(NOTIFICATION_ID) }
        }
    }

    private fun manager() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /** Playing: in the foreground (the service). Paused: the notification stays, out of the foreground. */
    private fun post(notification: Notification) {
        current = notification
        shown = true
        val service = AccompanimentService.running
        if (player.isPlaying) {
            if (service != null) service.foreground(notification)
            else if (!AccompanimentService.start(context)) runCatching { manager().notify(NOTIFICATION_ID, notification) }
        } else {
            service?.background()
            runCatching { manager().notify(NOTIFICATION_ID, notification) }
        }
    }

    private fun notification(session: MediaSession, title: String, artist: String, verse: String): Notification {
        val manager = manager()
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Accompaniment", NotificationManager.IMPORTANCE_LOW).apply {
                description = "The piano while it plays"
                setShowBadge(false)
            })
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val playing = player.isPlaying
        val restart = Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(context, android.R.drawable.ic_media_previous),
            "Restart", AccompanimentService.action(context, AccompanimentService.RESTART)).build()
        val toggle = Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(context,
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play),
            if (playing) "Pause" else "Play", AccompanimentService.action(context, AccompanimentService.TOGGLE)).build()
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_accompaniment)
            .setContentTitle(title)
            .setContentText(listOf(artist, verse).filter { it.isNotEmpty() }.joinToString(" · "))
            .setContentIntent(open)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .addAction(restart)
            .addAction(toggle)
        val compact = if (player.onNextTrack != null) {
            builder.addAction(Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(context, android.R.drawable.ic_media_next),
                "Next hymn", AccompanimentService.action(context, AccompanimentService.NEXT)).build())
            intArrayOf(0, 1, 2)
        } else intArrayOf(0, 1)
        builder.setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(*compact))
        return builder.build()
    }

    companion object {
        const val CHANNEL_ID = "accompaniment"
        const val NOTIFICATION_ID = 4107
        /** The latest notification, for the service to show in the foreground. */
        @Volatile internal var current: Notification? = null
    }
}

/**
 * Keeps the accompaniment playing with the app in the background (iOS's
 * audio background mode): a media-playback foreground service showing the
 * Now Playing notification, and the notification's buttons.
 *
 * Manifest (owned by church this wave):
 *     <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
 *     <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
 *     <service android:name=".audio.AccompanimentService" android:exported="false"
 *         android:foregroundServiceType="mediaPlayback" />
 */
class AccompanimentService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    override fun onDestroy() {
        if (running === this) running = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NowPlaying.current
        if (notification == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        foreground(notification)
        val player = (application as? AdventPraiseApp)?.services?.player
        when (intent?.action) {
            TOGGLE -> player?.toggle()
            RESTART -> player?.restart()
            NEXT -> player?.onNextTrack?.invoke()
        }
        return START_NOT_STICKY
    }

    fun foreground(notification: Notification) {
        runCatching {
            if (Build.VERSION.SDK_INT >= 29) startForeground(NowPlaying.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(NowPlaying.NOTIFICATION_ID, notification)
        }
    }

    /** Paused: out of the foreground, the notification left up. */
    fun background() {
        runCatching { stopForeground(STOP_FOREGROUND_DETACH) }
    }

    /** Stopped or finished: the notification goes too. */
    fun finish() {
        runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf()
    }

    companion object {
        const val TOGGLE = "com.mDev.AdventPraise.accompaniment.TOGGLE"
        const val RESTART = "com.mDev.AdventPraise.accompaniment.RESTART"
        const val NEXT = "com.mDev.AdventPraise.accompaniment.NEXT"

        @Volatile var running: AccompanimentService? = null
            private set

        /** Whether the service is in the manifest (the lead adds it). */
        fun isDeclared(context: Context): Boolean = runCatching {
            val component = android.content.ComponentName(context, AccompanimentService::class.java)
            if (Build.VERSION.SDK_INT >= 33) context.packageManager.getServiceInfo(component, PackageManager.ComponentInfoFlags.of(0))
            else @Suppress("DEPRECATION") context.packageManager.getServiceInfo(component, 0)
        }.isSuccess

        /** Starts it in the foreground; false when it isn't declared or may not start now. */
        fun start(context: Context): Boolean {
            if (!isDeclared(context)) return false
            return runCatching { context.startForegroundService(Intent(context, AccompanimentService::class.java)) != null }.getOrDefault(false)
        }

        fun action(context: Context, action: String): PendingIntent =
            PendingIntent.getService(context, action.hashCode(), Intent(context, AccompanimentService::class.java).setAction(action),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
