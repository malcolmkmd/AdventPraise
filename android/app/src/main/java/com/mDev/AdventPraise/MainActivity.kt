package com.mDev.AdventPraise

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.mDev.AdventPraise.ui.AdventPraiseRoot

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val services = (application as AdventPraiseApp).services
        setContent { AdventPraiseRoot(services) }
    }

    override fun onStop() {
        super.onStop()
        // No background playback yet: the accompaniment pauses when the app leaves the screen.
        val services = (application as AdventPraiseApp).services
        if (!isChangingConfigurations) services.player.pause()
    }
}
