package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * What a screen's stub draws until its area builds it: the iOS title, quietly.
 * Every use of this is a screen still to port.
 */
@Composable
fun PendingScreen(title: String, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    Column(
        modifier.fillMaxWidth().heightIn(min = 160.dp).padding(DS.Space.l),
        verticalArrangement = Arrangement.spacedBy(DS.Space.s, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = DS.Type.sheetTitle, color = p.foreground, textAlign = TextAlign.Center)
    }
}
