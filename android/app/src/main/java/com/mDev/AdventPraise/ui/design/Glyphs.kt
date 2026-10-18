package com.mDev.AdventPraise.ui.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/** SF Symbols the app uses that Material lacks, drawn to sit beside Material's outlined icons. */
object Glyphs {
    /** SF Symbols' `tuningfork`: the pitch pipe, wherever iOS shows it (More, the paywall, About this hymn). */
    val TuningFork: ImageVector by lazy {
        ImageVector.Builder("TuningFork", 24.dp, 24.dp, 24f, 24f).apply {
            // An upright fork turned 45°: the tines up and to the right, the handle down to the left.
            path(
                stroke = SolidColor(Color.Black), strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
            ) {
                moveTo(16.31f, 2.88f); lineTo(10.73f, 8.46f)
                curveTo(7.9f, 11.29f, 12.71f, 16.1f, 15.54f, 13.27f)
                lineTo(21.12f, 7.69f)
                moveTo(11.01f, 12.99f); lineTo(4.58f, 19.42f)
            }
        }.build()
    }
}
