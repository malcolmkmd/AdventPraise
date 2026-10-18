package com.mDev.AdventPraise.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * The one Hymn of the Day rule (HymnOfTheDayPicker.swift), a pure function
 * of the local calendar day, so iOS and Android pick the same hymn: day
 * index = whole local days since 1 Jan 2024. Days run in cycles of N (the
 * hymnal's size); inside a cycle the hymn is (a·pos + b) mod N, with a
 * coprime to N, so every hymn appears once per cycle and neighbouring days
 * are scattered. a and b come from a SplitMix64 hash of the cycle number.
 * The result is an index into the hymnal's `hymns`.
 */
object HymnOfTheDayPicker {
    private val epoch: LocalDate = LocalDate.of(2024, 1, 1)

    /** Whole local days from 1 Jan 2024 to `date` (negative before it). */
    fun dayIndex(date: LocalDate): Int = ChronoUnit.DAYS.between(epoch, date).toInt()

    fun dayIndex(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): Int = dayIndex(instant.atZone(zone).toLocalDate())

    fun index(date: LocalDate, count: Int): Int = index(dayIndex(date), count)

    /** Index into a hymnal of `count` hymns for a day. */
    fun index(dayIndex: Int, count: Int): Int {
        val n = count
        if (n <= 1) return 0
        val day = dayIndex
        val cycle = Math.floorDiv(day, n)
        val pos = day - cycle * n
        val h1 = splitMix64(cycle.toLong().toULong())
        val h2 = splitMix64(h1)
        // A multiplier coprime to n, other than 1 when there's a choice (1 would walk the hymnal in order).
        var a = (h1 % n.toULong()).toInt()
        if (n > 2 && a < 2) a = 2
        while (gcd(a, n) != 1) a = if (a + 1 >= n) 1 else a + 1
        val b = (h2 % n.toULong()).toInt()
        return ((a.toLong() * pos + b) % n).toInt()
    }

    fun splitMix64(seed: ULong): ULong {
        var z = seed + 0x9E3779B97F4A7C15uL
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }

    private tailrec fun gcd(a: Int, b: Int): Int = if (b == 0) a else gcd(b, a % b)
}

/**
 * Hymn of the day as the widget shows it (HymnOfTheDay in
 * ChurchWidgetState.swift): written by the app for the coming days.
 */
data class HymnOfTheDay(
    val date: LocalDate,
    val number: Int,
    val title: String,
    /** The hymnal's name, "Christ In Song". */
    val hymnal: String,
    /** The hymnal the number belongs to (numbers differ between hymnals). */
    val hymnalId: String?,
    /** The first verse. */
    val lines: List<String>,
) {
    /** Exactly the hymn shown: `adventpraise://hymn/<number>?hymnal=<id>`. */
    val url: String get() = "adventpraise://hymn/$number" + (hymnalId?.let { "?hymnal=$it" } ?: "")

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "date" to date.toString(), "number" to number, "title" to title, "hymnal" to hymnal,
        "hymnalID" to hymnalId, "lines" to lines,
    )

    companion object {
        const val WIDGET_KIND = "HymnOfTheDay"

        val placeholder = HymnOfTheDay(
            LocalDate.now(), 1, "Watchman Blow The Gospel Trumpet", "Christ In Song", null,
            listOf("Watchman, blow the gospel trumpet,", "Every soul a warning give;",
                "Whosoever hears the message", "May repent, and turn, and live."),
        )

        fun fromJson(value: Any?): HymnOfTheDay? = runCatching {
            val o = value.jsonObject()!!
            HymnOfTheDay(
                LocalDate.parse(o["date"].jsonString()!!), o["number"].jsonInt()!!, o["title"].jsonString()!!,
                o["hymnal"].jsonString()!!, o["hymnalID"].jsonString(), o["lines"].jsonArray()!!.map { it.jsonString()!! },
            )
        }.getOrNull()

        fun encodeAll(days: List<HymnOfTheDay>): String = Json.write(days.map { it.toJson() })
        fun decodeAll(text: String?): List<HymnOfTheDay> =
            text?.let(Json::parseOrNull).jsonArray().orEmpty().mapNotNull(::fromJson)
    }
}

/** The app's side of Hymn of the Day (HymnOfTheDayFeed): the hymn, and the days the widget shows. */
object HymnOfTheDayFeed {
    fun hymn(date: LocalDate, hymnal: Hymnal): Hymn? {
        if (hymnal.hymns.isEmpty()) return null
        return hymnal.hymns[HymnOfTheDayPicker.index(date, hymnal.hymns.size)]
    }

    fun hymn(instant: Instant, hymnal: Hymnal, zone: ZoneId = ZoneId.systemDefault()): Hymn? =
        hymn(instant.atZone(zone).toLocalDate(), hymnal)

    fun days(hymnal: Hymnal, from: LocalDate, count: Int): List<HymnOfTheDay> = (0 until count).mapNotNull { offset ->
        val date = from.plusDays(offset.toLong())
        val hymn = hymn(date, hymnal) ?: return@mapNotNull null
        val verse = hymn.blocks.firstOrNull { it is Block.Verse } ?: hymn.blocks.firstOrNull()
        HymnOfTheDay(date, hymn.number, hymn.title, hymnal.name, hymnal.id, verse?.lines.orEmpty())
    }

    /** True when `hymn` is today's Hymn of the Day in `hymnal`: its sheet music is free. */
    fun isToday(hymn: Hymn, hymnal: Hymnal, today: LocalDate = LocalDate.now()): Boolean =
        hymn(today, hymnal)?.number == hymn.number
}
