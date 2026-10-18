// OWNER: cast
package com.mDev.AdventPraise.cast

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.CastMediaOptions
import com.mDev.AdventPraise.BuildConfig

/**
 * The Cast framework's options (named in the manifest's
 * `com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME`). Only
 * read once [ChurchCast] initialises the CastContext, which it never does
 * without a receiver application ID.
 *
 * Our receiver speaks only the church namespace: no media session, no media
 * notification (the phone's own Now Playing stays the controls).
 */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions = CastOptions.Builder()
        .setReceiverApplicationId(BuildConfig.CAST_RECEIVER_APP_ID.trim())
        .setSupportedNamespaces(listOf(CastProtocol.NAMESPACE))
        .setCastMediaOptions(CastMediaOptions.Builder().setMediaSessionEnabled(false).setNotificationOptions(null).build())
        .setResumeSavedSession(true)
        .setStopReceiverApplicationWhenEndingSession(true)
        .build()

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}
