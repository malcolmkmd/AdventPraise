package com.mDev.AdventPraise.extras

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.ServicePlanEdit
import com.mDev.AdventPraise.data.Json
import com.mDev.AdventPraise.data.jsonArray
import com.mDev.AdventPraise.data.jsonInt
import com.mDev.AdventPraise.data.jsonObject
import com.mDev.AdventPraise.data.jsonString
import com.mDev.AdventPraise.settings.KeyValueStore
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.Locale
import java.util.UUID

/**
 * An ordered hymn list for a service ("Sabbath 14 June": opening, before
 * the sermon, closing). A plan belongs to one hymnal and runs in church
 * mode like a playlist, stopping after its last hymn (ServicePlan on iOS).
 */
data class ServicePlan(
    val id: String = newId(),
    val name: String,
    val hymnal: String,
    val date: LocalDate? = null,
    val items: List<Item> = emptyList(),
) {
    data class Item(
        val id: String = newId(),
        val number: Int,
        /** Where it falls in the service, e.g. "Opening hymn". Optional. */
        val role: String? = null,
    )

    val numbers: List<Int> get() = items.map { it.number }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id, "name" to name, "hymnal" to hymnal, "date" to date?.toString(),
        "items" to items.map { linkedMapOf("id" to it.id, "number" to it.number, "role" to it.role).filterValues { v -> v != null } },
    ).filterValues { it != null }

    companion object {
        fun newId(): String = UUID.randomUUID().toString().uppercase()

        fun fromJson(raw: Any?): ServicePlan? = runCatching {
            val o = raw.jsonObject()!!
            ServicePlan(
                id = o["id"].jsonString()!!,
                name = o["name"].jsonString()!!,
                hymnal = o["hymnal"].jsonString()!!,
                date = o["date"].jsonString()?.let(LocalDate::parse),
                items = o["items"].jsonArray().orEmpty().mapNotNull { item ->
                    val i = item.jsonObject() ?: return@mapNotNull null
                    Item(i["id"].jsonString() ?: newId(), i["number"].jsonInt() ?: return@mapNotNull null, i["role"].jsonString())
                },
            )
        }.getOrNull()
    }
}

/**
 * The service plans, saved under "service.plans.v1" (ServicePlanner on
 * iOS). Dates are local days ("2026-10-24"); iOS keeps a Date.
 */
class ServicePlanner(
    private val store: KeyValueStore,
    private val today: () -> LocalDate = { LocalDate.now() },
    /** "Saturday 24 October" in the person's locale. */
    private val nameForDate: (LocalDate) -> String = ::defaultName,
) {
    var plans: List<ServicePlan> by mutableStateOf(load())
        private set

    /** A plan's plans for one hymnal, newest date first, then by name (descending, as iOS). */
    fun plans(hymnal: String): List<ServicePlan> = plans.filter { it.hymnal == hymnal }
        .sortedWith(compareByDescending<ServicePlan> { it.date ?: LocalDate.MIN }.thenByDescending { it.name })

    fun plan(id: String): ServicePlan? = plans.firstOrNull { it.id == id }

    /** A new plan for the coming Sabbath (today if it's Saturday), named for its date. */
    fun newPlan(hymnal: String, numbers: List<Int> = emptyList()): ServicePlan {
        val date = nextSabbath(today())
        val plan = ServicePlan(name = nameForDate(date), hymnal = hymnal, date = date, items = numbers.map { ServicePlan.Item(number = it) })
        set(plans + plan)
        Analytics.track(AnalyticsEvent.ServicePlanCreated(plan.items.size))
        return plan
    }

    /** Every edit from the plan editor. Name and date changes aren't tracked; hymn changes are. */
    fun update(plan: ServicePlan) {
        val i = plans.indexOfFirst { it.id == plan.id }
        if (i < 0) return
        val old = plans[i]
        set(plans.toMutableList().also { it[i] = plan })
        edit(old, plan)?.let { Analytics.track(AnalyticsEvent.ServicePlanEdited(it, plan.items.size)) }
    }

    fun delete(plan: ServicePlan) {
        set(plans.filterNot { it.id == plan.id })
        Analytics.track(AnalyticsEvent.ServicePlanDeleted(plan.items.size))
    }

    fun add(number: Int, planId: String) {
        val i = plans.indexOfFirst { it.id == planId }
        if (i < 0) return
        val next = plans[i].copy(items = plans[i].items + ServicePlan.Item(number = number))
        set(plans.toMutableList().also { it[i] = next })
        Analytics.track(AnalyticsEvent.ServicePlanEdited(ServicePlanEdit.HymnAdded, next.items.size))
    }

    private fun set(next: List<ServicePlan>) {
        plans = next
        store.putString(KEY, Json.write(next.map { it.toJson() }))
    }

    private fun load(): List<ServicePlan> =
        store.getString(KEY)?.let(Json::parseOrNull).jsonArray().orEmpty().mapNotNull(ServicePlan::fromJson)

    companion object {
        const val KEY = "service.plans.v1"

        /** Suggested roles; any text is allowed. */
        val ROLES = listOf("Opening hymn", "Hymn of praise", "Before the sermon", "Response", "Closing hymn")

        /** Today if it is Saturday, otherwise the coming Saturday. */
        fun nextSabbath(today: LocalDate): LocalDate = today.with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY))

        fun edit(old: ServicePlan, new: ServicePlan): ServicePlanEdit? = when {
            new.items.size > old.items.size -> ServicePlanEdit.HymnAdded
            new.items.size < old.items.size -> ServicePlanEdit.HymnRemoved
            new.items.map { it.id } != old.items.map { it.id } -> ServicePlanEdit.Reordered
            new.items.map { it.role } != old.items.map { it.role } -> ServicePlanEdit.RoleSet
            else -> null
        }

        fun defaultName(date: LocalDate): String {
            val locale = Locale.getDefault()
            val pattern = runCatching { android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEdMMMM") }.getOrNull()
                ?: "EEEE d MMMM"
            return date.format(DateTimeFormatter.ofPattern(pattern, locale))
        }
    }
}
