package com.mDev.AdventPraise.ui.extras

import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.extras.ServicePlan
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.ui.design.HapticEvent
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate

/** The service plan editor and the plans list's grouping (ServicePlannerView's edits and date helpers). */
class ServicePlanEditorTest {
    private val hymnal = Hymnal(
        HymnalInfo("english", "Christ In Song", "English", 4, 400), "Chorus",
        listOf(1, 12, 100, 254).map { Hymn(it, "Hymn $it", emptyList(), emptyList(), null) },
    )
    private val today = LocalDate.of(2026, 10, 21) // a Wednesday
    private val store = MemoryStore()
    private val planner = ServicePlanner(store, today = { today }, nameForDate = { "Sabbath ${it.dayOfMonth}" })
    private val haptics = mutableListOf<HapticEvent>()
    private val sent = mutableListOf<AnalyticsEvent>()

    @Before fun listen() { Analytics.testSink = { sent += it } }
    @After fun stop() { Analytics.testSink = null }

    private fun editor(numbers: List<Int> = listOf(1, 12, 100)): ServicePlanEditor {
        val plan = planner.newPlan(hymnal.id, numbers)
        sent.clear()
        return ServicePlanEditor(planner, plan.id, hymnal) { haptics += it }
    }

    private fun ServicePlanEditor.numbers() = plan!!.numbers

    @Test fun aNewPlanIsForTheComingSabbath() {
        val plan = editor().plan!!
        assertEquals(LocalDate.of(2026, 10, 24), plan.date)
        assertEquals("Sabbath 24", plan.name)
    }

    @Test fun movesSwapNeighboursAndStopAtTheEnds() {
        val e = editor()
        val first = e.plan!!.items[0].id
        assertFalse(e.canMove(first, -1))
        assertTrue(e.canMove(first, 1))
        e.move(first, 1)
        assertEquals(listOf(12, 1, 100), e.numbers())
        assertEquals(HapticEvent.Selection, haptics.single())
        assertEquals("reordered", sent.single().properties["action"])

        val last = e.plan!!.items.last().id
        e.move(last, 1)
        assertEquals(listOf(12, 1, 100), e.numbers())
        assertEquals(1, haptics.size)
    }

    @Test fun removeAndRolesAreSavedAndTracked() {
        val e = editor()
        val middle = e.plan!!.items[1].id
        e.setRole(middle, ServicePlanner.ROLES.first())
        assertEquals("Opening hymn", e.plan!!.items[1].role)
        assertEquals("role_set", sent.last().properties["action"])
        e.setRole(middle, null)
        assertNull(e.plan!!.items[1].role)

        e.remove(middle)
        assertEquals(listOf(1, 100), e.numbers())
        assertEquals("hymn_removed", sent.last().properties["action"])
        assertEquals(2, sent.last().properties["hymn_count"])
        // Saved under the iOS key: a fresh planner reads it back.
        assertEquals(listOf(1, 100), ServicePlanner(store).plan(e.planId)!!.numbers)
    }

    @Test fun nameAndDateEditsAreNotTracked() {
        val e = editor()
        e.setName("Communion Sabbath")
        e.setDate(LocalDate.of(2026, 11, 7))
        assertEquals("Communion Sabbath", e.plan!!.name)
        assertEquals(LocalDate.of(2026, 11, 7), e.plan!!.date)
        assertTrue(sent.isEmpty())
    }

    @Test fun addingByNumberTakesOnlyHymnsTheHymnalHas() {
        val e = editor(emptyList())
        e.setNumber("2a5 4")
        assertEquals("254", e.numberText)
        assertEquals("Hymn 254", e.typedCaption)
        assertTrue(e.canAddTyped)
        assertTrue(e.addTypedNumber())
        assertEquals(listOf(254), e.numbers())
        assertEquals("", e.numberText)
        assertEquals("hymn_added", sent.last().properties["action"])

        e.setNumber("5")
        assertEquals("No hymn 5 in Christ In Song", e.typedCaption)
        assertFalse(e.canAddTyped)
        assertFalse(e.addTypedNumber())
        assertEquals("5", e.numberText)
        assertEquals(listOf(254), e.numbers())
    }

    @Test fun theHymnBeingReadIsOfferedUntilItIsInThePlan() {
        val e = editor(listOf(1))
        assertTrue(e.offersCurrent(12))
        e.addCurrent(12)
        assertFalse(e.offersCurrent(12))
        assertEquals(listOf(1, 12), e.numbers())
    }

    @Test fun onlyHymnsInTheHymnalArePlayable() {
        val e = editor(listOf(7, 12, 999, 1))
        assertEquals(listOf(12, 1), e.playable)
        assertTrue(editor(listOf(7)).playable.isEmpty())
    }

    @Test fun aDeletedPlanLeavesNothingToEdit() {
        val e = editor()
        planner.delete(e.plan!!)
        assertNull(e.plan)
        e.move("x", 1)
        e.remove("x")
        assertTrue(haptics.isEmpty())
    }

    @Test fun theListLeadsWithTheNextServiceThenComingUpThenPast() {
        fun plan(name: String, date: LocalDate?) = ServicePlan(name = name, hymnal = "english", date = date)
        val past = plan("Last week", today.minusDays(4))
        val next = plan("This Sabbath", today.plusDays(3))
        val later = plan("Next month", today.plusDays(30))
        val undated = plan("Someday", null)
        val sections = PlanSections.of(listOf(later, next, undated, past), today)
        assertEquals(next, sections.next)
        assertEquals(listOf(later, undated), sections.comingUp)
        assertEquals(listOf(past), sections.past)
        assertTrue(PlanSections.of(emptyList(), today).isEmpty)
        assertEquals(undated, PlanSections.of(listOf(undated, past), today).next)
    }

    @Test fun relativeDaysAndSummaries() {
        fun on(days: Long) = ServicePlan(name = "p", hymnal = "english", date = today.plusDays(days))
        assertEquals("Today", PlanText.relativeDay(on(0), today))
        assertEquals("Tomorrow", PlanText.relativeDay(on(1), today))
        assertEquals("In 3 days", PlanText.relativeDay(on(3), today))
        assertEquals("In 13 days", PlanText.relativeDay(on(13), today))
        assertNull(PlanText.relativeDay(on(14), today))
        assertNull(PlanText.relativeDay(on(-1), today))
        assertTrue(PlanText.isUpcoming(on(0), today))
        assertFalse(PlanText.isUpcoming(on(-1), today))

        val plan = ServicePlan(name = "p", hymnal = "english", items = listOf(1, 12, 100, 412).map { ServicePlan.Item(number = it) })
        assertEquals("4 hymns · 1 · 12 · 100 · 412", PlanText.hymnSummary(plan))
        assertEquals("1 hymn · 7", PlanText.hymnSummary(plan.copy(items = listOf(ServicePlan.Item(number = 7)))))
        assertEquals("No hymns", PlanText.hymnSummary(plan.copy(items = emptyList())))
    }
}
