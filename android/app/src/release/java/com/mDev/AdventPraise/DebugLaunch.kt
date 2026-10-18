package com.mDev.AdventPraise

import android.content.Intent

/** Release builds ignore the debug launch extras (the real one is in src/debug). */
object DebugLaunch {
    @Suppress("UNUSED_PARAMETER")
    fun apply(intent: Intent?, services: AppServices) = Unit
}
