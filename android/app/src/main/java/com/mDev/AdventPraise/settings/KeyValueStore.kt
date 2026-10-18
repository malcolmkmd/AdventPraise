package com.mDev.AdventPraise.settings

import android.content.Context
import android.content.SharedPreferences

/**
 * Where the app keeps small values between launches: UserDefaults on iOS.
 * Every persisted setting goes through this, so the rules can be tested
 * with [MemoryStore] and the backing (SharedPreferences today, DataStore
 * later) can change in one place. Keys are the iOS app's.
 */
interface KeyValueStore {
    fun contains(key: String): Boolean
    fun getString(key: String): String?
    fun getInt(key: String): Int?
    fun getLong(key: String): Long?
    fun getFloat(key: String): Float?
    fun getBoolean(key: String): Boolean?
    fun getStringSet(key: String): Set<String>?

    fun putString(key: String, value: String?)
    fun putInt(key: String, value: Int?)
    fun putLong(key: String, value: Long?)
    fun putFloat(key: String, value: Float?)
    fun putBoolean(key: String, value: Boolean?)
    fun putStringSet(key: String, value: Set<String>?)
    fun remove(key: String)

    fun getBoolean(key: String, default: Boolean): Boolean = getBoolean(key) ?: default
    fun getInt(key: String, default: Int): Int = getInt(key) ?: default
}

/** SharedPreferences behind [KeyValueStore]. Writes are applied asynchronously. */
class SharedPreferencesStore(private val prefs: SharedPreferences) : KeyValueStore {
    constructor(context: Context, name: String) : this(context.getSharedPreferences(name, Context.MODE_PRIVATE))

    override fun contains(key: String) = prefs.contains(key)
    override fun getString(key: String): String? = if (prefs.contains(key)) runCatching { prefs.getString(key, null) }.getOrNull() else null
    override fun getInt(key: String): Int? = if (prefs.contains(key)) runCatching { prefs.getInt(key, 0) }.getOrNull() else null
    override fun getLong(key: String): Long? = if (prefs.contains(key)) runCatching { prefs.getLong(key, 0) }.getOrNull() else null
    override fun getFloat(key: String): Float? = if (prefs.contains(key)) runCatching { prefs.getFloat(key, 0f) }.getOrNull() else null
    override fun getBoolean(key: String): Boolean? = if (prefs.contains(key)) runCatching { prefs.getBoolean(key, false) }.getOrNull() else null
    override fun getStringSet(key: String): Set<String>? =
        if (prefs.contains(key)) runCatching { prefs.getStringSet(key, null)?.toSet() }.getOrNull() else null

    override fun putString(key: String, value: String?) = edit(key, value) { putString(key, it) }
    override fun putInt(key: String, value: Int?) = edit(key, value) { putInt(key, it) }
    override fun putLong(key: String, value: Long?) = edit(key, value) { putLong(key, it) }
    override fun putFloat(key: String, value: Float?) = edit(key, value) { putFloat(key, it) }
    override fun putBoolean(key: String, value: Boolean?) = edit(key, value) { putBoolean(key, it) }
    override fun putStringSet(key: String, value: Set<String>?) = edit(key, value) { putStringSet(key, it) }
    override fun remove(key: String) = prefs.edit().remove(key).apply()

    private inline fun <T : Any> edit(key: String, value: T?, crossinline put: SharedPreferences.Editor.(T) -> Unit) {
        val editor = prefs.edit()
        if (value == null) editor.remove(key) else editor.put(value)
        editor.apply()
    }
}

/** In memory: tests, previews and screenshot fixtures. */
class MemoryStore(initial: Map<String, Any> = emptyMap()) : KeyValueStore {
    val values: MutableMap<String, Any> = initial.toMutableMap()
    /** How many writes landed (tests count them). */
    var writes = 0
        private set

    override fun contains(key: String) = key in values
    override fun getString(key: String) = values[key] as? String
    override fun getInt(key: String) = (values[key] as? Number)?.toInt()
    override fun getLong(key: String) = (values[key] as? Number)?.toLong()
    override fun getFloat(key: String) = (values[key] as? Number)?.toFloat()
    override fun getBoolean(key: String) = values[key] as? Boolean
    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String) = (values[key] as? Set<String>)?.toSet()

    override fun putString(key: String, value: String?) = put(key, value)
    override fun putInt(key: String, value: Int?) = put(key, value)
    override fun putLong(key: String, value: Long?) = put(key, value)
    override fun putFloat(key: String, value: Float?) = put(key, value)
    override fun putBoolean(key: String, value: Boolean?) = put(key, value)
    override fun putStringSet(key: String, value: Set<String>?) = put(key, value?.toSet())
    override fun remove(key: String) { values.remove(key); writes++ }

    private fun put(key: String, value: Any?) {
        if (value == null) values.remove(key) else values[key] = value
        writes++
    }
}
