// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.ServicePlan
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** How plans read in the list and the editor (ServicePlan's date helpers in ServicePlannerView.swift). */
object PlanText {
    /** Today or later; a plan without a date counts as coming up. */
    fun isUpcoming(plan: ServicePlan, today: LocalDate): Boolean = plan.date?.let { !it.isBefore(today) } ?: true

    /** "Saturday 24 October" in the person's locale. */
    fun dateText(plan: ServicePlan): String? = plan.date?.let(ServicePlanner::defaultName)

    /** "Today", "Tomorrow", "In 3 days" within the next two weeks. */
    fun relativeDay(plan: ServicePlan, today: LocalDate): String? {
        val date = plan.date ?: return null
        return when (val days = ChronoUnit.DAYS.between(today, date)) {
            0L -> "Today"
            1L -> "Tomorrow"
            in 2L..13L -> "In $days days"
            else -> null
        }
    }

    /** "4 hymns · 1 · 12 · 100 · 412", or "No hymns". */
    fun hymnSummary(plan: ServicePlan): String {
        if (plan.items.isEmpty()) return "No hymns"
        return (listOf(hymnCount(plan.items.size)) + plan.numbers.map(Int::toString)).joinToString(" · ")
    }

    /** "OCT" over "24" on a plan's calendar tile. */
    fun monthAbbreviation(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        date.format(DateTimeFormatter.ofPattern("LLL", locale)).trimEnd('.')
}

/** The plans list's three parts: the next service, the others coming up, and the past. */
data class PlanSections(val next: ServicePlan?, val comingUp: List<ServicePlan>, val past: List<ServicePlan>) {
    val isEmpty: Boolean get() = next == null && comingUp.isEmpty() && past.isEmpty()

    companion object {
        /** [plans] as ServicePlanner.plans(hymnal) orders them (newest date first). */
        fun of(plans: List<ServicePlan>, today: LocalDate): PlanSections {
            val sortDate = { p: ServicePlan -> p.date ?: LocalDate.MAX }
            val upcoming = plans.filter { PlanText.isUpcoming(it, today) }
            val next = upcoming.minByOrNull(sortDate)
            val comingUp = upcoming.filter { it.id != next?.id }.sortedBy(sortDate)
            return PlanSections(next, comingUp, plans.filterNot { PlanText.isUpcoming(it, today) })
        }
    }
}

/**
 * One plan in the editor (ServicePlanPage's edits): its name and date, each
 * hymn's role, moves and removal, and adding hymns, the one being read or by
 * number. Every edit goes through [ServicePlanner.update], which sends the
 * hymn changes to analytics as iOS does.
 */
class ServicePlanEditor(
    private val planner: ServicePlanner,
    val planId: String,
    private val hymnal: Hymnal,
    private val haptic: (HapticEvent) -> Unit = Haptics::play,
) {
    val plan: ServicePlan? get() = planner.plan(planId)

    /** The add-by-number field. */
    var numberText by mutableStateOf("")
        private set

    /** The plan's hymns this hymnal has: what church mode can sing. */
    val playable: List<Int> get() = plan?.numbers.orEmpty().filter { hymnal.hymn(it) != null }

    fun setName(name: String) = edit { it.copy(name = name) }

    fun setDate(date: LocalDate?) = edit { it.copy(date = date) }

    fun setRole(itemId: String, role: String?) = edit { plan ->
        plan.copy(items = plan.items.map { if (it.id == itemId) it.copy(role = role) else it })
    }

    fun canMove(itemId: String, step: Int): Boolean {
        val items = plan?.items ?: return false
        val from = items.indexOfFirst { it.id == itemId }
        return from >= 0 && (from + step) in items.indices
    }

    /** -1 up, +1 down. */
    fun move(itemId: String, step: Int) {
        val current = plan ?: return
        val from = current.items.indexOfFirst { it.id == itemId }
        val to = from + step
        if (from < 0 || to !in current.items.indices) return
        val items = current.items.toMutableList()
        items[from] = current.items[to]
        items[to] = current.items[from]
        planner.update(current.copy(items = items))
        haptic(HapticEvent.Selection)
    }

    fun remove(itemId: String) {
        val current = plan ?: return
        planner.update(current.copy(items = current.items.filterNot { it.id == itemId }))
        haptic(HapticEvent.Selection)
    }

    /** "The hymn you're reading" shows while the plan doesn't have it. */
    fun offersCurrent(number: Int): Boolean = number !in plan?.numbers.orEmpty()

    fun addCurrent(number: Int) {
        planner.add(number, planId)
        haptic(HapticEvent.Selection)
    }

    /** The field takes digits only (the number pad keyboard). */
    fun setNumber(text: String) {
        numberText = text.filter(Char::isDigit).take(4)
    }

    val typedNumber: Int? get() = numberText.toIntOrNull()

    /** Under the field: the typed hymn's title, or that the hymnal lacks it. */
    val typedCaption: String?
        get() {
            val number = typedNumber ?: return null
            return hymnal.hymn(number)?.title ?: "No hymn $number in ${hymnal.name}"
        }

    val canAddTyped: Boolean get() = typedNumber?.let(hymnal::hymn) != null

    /** Adds the typed number when the hymnal has it, and clears the field. */
    fun addTypedNumber(): Boolean {
        val number = typedNumber ?: return false
        if (hymnal.hymn(number) == null) return false
        planner.add(number, planId)
        numberText = ""
        haptic(HapticEvent.Selection)
        return true
    }

    private fun edit(change: (ServicePlan) -> ServicePlan) {
        val current = plan ?: return
        planner.update(change(current))
    }
}
