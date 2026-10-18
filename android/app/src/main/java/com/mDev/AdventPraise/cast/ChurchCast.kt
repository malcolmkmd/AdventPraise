// OWNER: cast
package com.mDev.AdventPraise.cast

import android.app.Application
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import androidx.compose.runtime.snapshotFlow
import androidx.core.content.ContextCompat
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.AccompanimentTransport
import com.mDev.AdventPraise.audio.StandardMidiFile
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.church.display.TvOutput
import com.mDev.AdventPraise.church.display.TvOutputState
import com.mDev.AdventPraise.church.display.TvRoute
import com.mDev.AdventPraise.church.display.TvRouteKind
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.settings.ReadingSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * Church mode on a Google Cast TV with our custom Web Receiver
 * (android/cast-receiver): the TV shows the worship display and plays the
 * accompaniment; the phone is silent and follows the TV's clock.
 *
 * Off entirely (no Cast routes, nothing initialised) when the build has no
 * receiver application ID (`cast.receiverAppId`) or the device has no Google
 * Play services. The [tv] output joins church mode's TV chooser (TvOutputs).
 */
class ChurchCast(
    private val app: Application,
    private val scope: CoroutineScope,
    private val session: ChurchSession,
    private val settings: ReadingSettings,
    player: AccompanimentPlayer,
    local: AccompanimentTransport,
    /** The hymnal's chorus label, when the reader has that hymnal open. */
    chorusLabel: (HymnalInfo) -> String?,
    /** A church picture by its ChurchImages id. */
    private val picture: (String) -> Bitmap?,
) {
    val receiverAppId: String = BuildConfig.CAST_RECEIVER_APP_ID.trim()
    val isConfigured: Boolean get() = receiverAppId.isNotEmpty()

    private val passLengths = HashMap<String, Long>()

    val transport = CastTransport(
        scope = scope,
        now = SystemClock::elapsedRealtime,
        passLengthMs = ::passLength,
        wordsFor = { hymn, info -> words(hymn, info, chorusLabel) },
    )

    private val pictures = CastPictures(
        send = { transport.sendScreen(it) },
        load = { id -> withContext(Dispatchers.IO) { picture(id)?.let(::fittedJpeg) } },
        launch = { block -> scope.launch { block() } },
    )
    private val mirror = CastChurchMirror(transport, pictures)
    private val engagement = CastEngagement(player, local, transport, mirror, ::scene)

    /** Church mode's TV chooser entry: Cast receivers, the one connected, and whether it shows the words. */
    val tv: TvOutput = Output()

    init {
        transport.screen = { mirror.current?.screen ?: scene().screen }
    }

    private fun scene(): CastScene = CastScene.of(session.current, settings.worshipPointSize, settings.largePrint)

    private fun words(hymn: Hymn, info: HymnalInfo, chorusLabel: (HymnalInfo) -> String?): CastWords {
        val church = session.current
        if (church.hymn?.number == hymn.number && church.hymnalId == info.id) {
            return CastWords(hymn, info.id, church.hymnalName, church.chorusLabel)
        }
        return CastWords(hymn, info.id, info.name, chorusLabel(info) ?: "Chorus")
    }

    private fun passLength(asset: String): Long? = passLengths[asset] ?: runCatching {
        app.assets.open(asset).use { StandardMidiFile.parse(it.readBytes()) }.lengthSeconds
    }.getOrNull()?.takeIf { it > 0 }?.let { (it * 1000).roundToLong() }?.also { passLengths[asset] = it }

    // MARK: The TV output

    private inner class Output : TvOutput {
        private val mutable = MutableStateFlow(TvOutputState())
        override val state: StateFlow<TvOutputState> = mutable.asStateFlow()

        private var context: CastContext? = null
        private var router: MediaRouter? = null
        private var selector: MediaRouteSelector? = null
        private var started = false
        private var discovering: Boolean? = null
        private var routes: List<TvRoute> = emptyList()
        private var connected: TvRoute? = null
        private var castSession: CastSession? = null

        private val routerCallback = object : MediaRouter.Callback() {
            override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = refreshRoutes()
            override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = refreshRoutes()
            override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = refreshRoutes()
            override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) = refreshRoutes()
            override fun onRouteUnselected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) = refreshRoutes()
        }

        private val sessionListener = object : SessionManagerListener<CastSession> {
            override fun onSessionStarted(session: CastSession, sessionId: String) = attach(session)
            override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = attach(session)
            override fun onSessionEnded(session: CastSession, error: Int) = detach()
            override fun onSessionStartFailed(session: CastSession, error: Int) = detach()
            override fun onSessionResumeFailed(session: CastSession, error: Int) = detach()
            override fun onSessionEnding(session: CastSession) = Unit
            override fun onSessionStarting(session: CastSession) = Unit
            override fun onSessionResuming(session: CastSession, sessionId: String) = Unit
            override fun onSessionSuspended(session: CastSession, reason: Int) = Unit
        }

        override fun start() {
            if (started || !isConfigured) return
            started = true
            val available = runCatching {
                GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(app) == ConnectionResult.SUCCESS
            }.getOrDefault(false)
            if (!available) { Log.i(TAG, "Cast off: no Google Play services"); return }
            runCatching {
                CastContext.getSharedInstance(app, ContextCompat.getMainExecutor(app))
                    .addOnSuccessListener { ready(it) }
                    .addOnFailureListener { Log.w(TAG, "Cast off: ${it.javaClass.simpleName}", it) }
            }.onFailure { Log.w(TAG, "Cast off: ${it.javaClass.simpleName}", it) }
        }

        private fun ready(cast: CastContext) = runCatching {
            context = cast
            router = MediaRouter.getInstance(app)
            selector = MediaRouteSelector.Builder()
                .addControlCategory(CastMediaControlIntent.categoryForCast(receiverAppId))
                .build()
            cast.sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
            // Look for TVs actively only while church mode is open (it costs battery).
            session.state.map { it.isActive }.distinctUntilChanged().onEach(::discover).launchIn(scope)
            session.state.map { it.isPro }.distinctUntilChanged().onEach {
                engagement.proChanged(it)
                publish()
            }.launchIn(scope)
            combine(session.state, snapshotFlow { settings.worshipPointSize to settings.largePrint }) { state, (size, large) ->
                CastScene.of(state, size, large)
            }.distinctUntilChanged().onEach(engagement::sceneChanged).launchIn(scope)
            cast.sessionManager.currentCastSession?.takeIf { it.isConnected }?.let(::attach)
            refreshRoutes()
        }.onFailure { Log.w(TAG, "Cast off: ${it.javaClass.simpleName}", it) }

        private fun discover(active: Boolean) {
            val r = router ?: return
            val s = selector ?: return
            if (discovering == active) return
            discovering = active
            r.addCallback(s, routerCallback, if (active) MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY else 0)
        }

        private fun refreshRoutes() {
            val r = router ?: return
            val s = selector ?: return
            routes = r.routes
                .filter { !it.isDefault && it.isEnabled && it.matchesSelector(s) }
                .map { TvRoute(ROUTE_PREFIX + it.id, it.name, TvRouteKind.Cast) }
            val selected = r.selectedRoute.takeIf { !it.isDefault && it.matchesSelector(s) }
            if (castSession != null && selected != null) connected = TvRoute(ROUTE_PREFIX + selected.id, selected.name, TvRouteKind.Cast)
            publish()
        }

        private fun attach(cast: CastSession) {
            castSession = cast
            runCatching {
                cast.setMessageReceivedCallbacks(CastProtocol.NAMESPACE) { _, _, message ->
                    val at = SystemClock.elapsedRealtime()
                    scope.launch { transport.receive(message, at) }
                }
            }.onFailure { Log.w(TAG, "Cast channel: ${it.javaClass.simpleName}", it) }
            val device = cast.castDevice
            val selected = router?.selectedRoute?.takeIf { selector?.let(it::matchesSelector) == true && !it.isDefault }
            connected = when {
                selected != null -> TvRoute(ROUTE_PREFIX + selected.id, selected.name, TvRouteKind.Cast)
                device != null -> TvRoute(ROUTE_PREFIX + device.deviceId, device.friendlyName ?: "TV", TvRouteKind.Cast)
                else -> TvRoute(ROUTE_PREFIX + "session", "TV", TvRouteKind.Cast)
            }
            engagement.connected(SessionChannel(cast))
            publish()
        }

        private fun detach() {
            castSession?.let { s -> runCatching { s.removeMessageReceivedCallbacks(CastProtocol.NAMESPACE) } }
            castSession = null
            connected = null
            engagement.disconnected()
            publish()
        }

        private fun publish() {
            val on = connected
            val list = if (on != null && routes.none { it.id == on.id }) routes + on else routes
            mutable.value = TvOutputState(list, on, on != null && session.current.isPro)
        }

        override fun stop() {
            router?.removeCallback(routerCallback)
            discovering = null
        }

        override fun select(route: TvRoute) {
            val r = router ?: return
            val target = r.routes.firstOrNull { ROUTE_PREFIX + it.id == route.id } ?: return
            // The Cast framework starts a session for the selected Cast route.
            runCatching { r.selectRoute(target) }.onFailure { Log.w(TAG, "Cast select: ${it.javaClass.simpleName}", it) }
        }

        override fun disconnect() {
            runCatching { context?.sessionManager?.endCurrentSession(true) }
        }
    }

    /** Our namespace on a connected session. */
    private class SessionChannel(private val session: CastSession) : CastChannel {
        override fun send(message: SenderMessage): Boolean = runCatching {
            session.sendMessage(CastProtocol.NAMESPACE, message.toJson())
            true
        }.getOrElse {
            Log.w(TAG, "Cast send ${message.type}: ${it.javaClass.simpleName}")
            false
        }
    }

    companion object {
        private const val TAG = "ChurchCast"
        private const val ROUTE_PREFIX = "cast:"

        /** Fitted inside 1920 × 1080 (never enlarged), JPEG. */
        fun fittedJpeg(bitmap: Bitmap): ByteArray {
            val scale = min(1f, min(CastProtocol.IMAGE_MAX_WIDTH.toFloat() / bitmap.width, CastProtocol.IMAGE_MAX_HEIGHT.toFloat() / bitmap.height))
            val fitted = if (scale < 1f) {
                Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).roundToInt().coerceAtLeast(1),
                    (bitmap.height * scale).roundToInt().coerceAtLeast(1), true)
            } else bitmap
            return ByteArrayOutputStream().use { out ->
                fitted.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                out.toByteArray()
            }
        }

        private const val JPEG_QUALITY = 85
    }
}
