package com.mDev.AdventPraise.billing

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.settings.KeyValueStore
import com.mDev.AdventPraise.settings.SharedPreferencesStore

/**
 * The counting, with nothing stored (FreePlayAllowance on iOS): every free
 * user gets [FREE] plays of the accompaniment. A play is a hymn starting
 * from the top; a resume, a scrub or a restart while the hymn is still up
 * is part of the same play (the player decides that).
 */
class FreePlayAllowance(used: Int = 0) {
    val used: Int = maxOf(0, used)
    override fun equals(other: Any?) = other is FreePlayAllowance && other.used == used
    override fun hashCode() = used
    override fun toString() = "FreePlayAllowance(used=$used)"
    val remaining: Int get() = maxOf(0, FREE - used)
    val isUsedUp: Boolean get() = remaining == 0
    /** The play being started now is the last free one. */
    val isLastPlay: Boolean get() = remaining == 1

    /** Counts one play: the new allowance, or null (nothing counted) once none are left. */
    fun spend(): FreePlayAllowance? = if (isUsedUp) null else FreePlayAllowance(used + 1)

    companion object {
        const val FREE = 5

        /** The stored counts can disagree: the most plays used wins. */
        fun reconciled(counts: List<Int?>): FreePlayAllowance = FreePlayAllowance(counts.filterNotNull().maxOrNull() ?: 0)
    }
}

/** Somewhere the used count is kept. */
interface FreePlayStorage {
    fun read(): Int?
    fun write(used: Int)
}

/**
 * The names the count is kept under (FreePlayStorageName). Versioned, and a
 * debug build keeps its own, so a developer's count never reaches release.
 */
object FreePlayStorageName {
    const val RELEASE = "freePlays.v2"
    const val DEBUG = "$RELEASE.debug"
    /** The first milestone's preferences file, never read. */
    const val LEGACY = "freePlays.v1"
    val current: String get() = if (BuildConfig.DEBUG) DEBUG else RELEASE
}

/** One [KeyValueStore] key. */
class StoreFreePlayStorage(private val store: KeyValueStore, private val key: String = FreePlayStorageName.current + ".used") : FreePlayStorage {
    override fun read(): Int? = store.getInt(key)
    override fun write(used: Int) = store.putInt(key, used)
}

/**
 * The free-play counter. iOS keeps the count in UserDefaults and the
 * Keychain so a reinstall doesn't hand out five more; on Android the count
 * lives in its own preferences file, which Auto Backup restores on a
 * reinstall (the platform's closest match to the Keychain). Several stores
 * may be given: the higher count wins, and all are brought up to it.
 * Pro never counts, and nothing played during the onboarding tour counts.
 */
class FreePlays(private val stores: List<FreePlayStorage>) {
    constructor(context: Context) : this(listOf(
        StoreFreePlayStorage(SharedPreferencesStore(context, FreePlayStorageName.current)),
    ))

    var allowance by mutableStateOf(FreePlayAllowance.reconciled(stores.map { it.read() }))
        private set

    init {
        save()
    }

    /** The onboarding tour is running: a play started now is neither counted nor locked. */
    var isTourActive by mutableStateOf(false)

    val used: Int get() = allowance.used
    val remaining: Int get() = allowance.remaining
    val isUsedUp: Boolean get() = allowance.isUsedUp
    /** A new play by a free user would open the paywall: the plays are used up, and this isn't the tour. */
    val locksNewPlay: Boolean get() = isUsedUp && !isTourActive

    /** A new play has started: counts it, and returns how many are left. During the tour nothing is counted. */
    fun spend(): Int {
        if (isTourActive) return allowance.remaining
        allowance.spend()?.let {
            allowance = it
            save()
        }
        return allowance.remaining
    }

    /** Debug and screenshots: sets the count. */
    fun debugSet(used: Int) {
        allowance = FreePlayAllowance(used)
        stores.forEach { it.write(allowance.used) }
    }

    private fun save() {
        for (store in stores) if (store.read() != allowance.used) store.write(allowance.used)
    }

    companion object {
        const val FREE = FreePlayAllowance.FREE
    }
}
