package com.mDev.AdventPraise.analytics

import com.mDev.AdventPraise.data.Json
import com.mDev.AdventPraise.extras.ExtraSheet
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.ScriptureConfidence
import com.mDev.AdventPraise.extras.SheetMusicAccess
import com.mDev.AdventPraise.settings.ReadingSurface
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The events keep the names and properties PostHog already has from iOS (Services/AnalyticsEvent.swift). */
class AnalyticsEventTest {
    @After fun tearDown() {
        Analytics.testSink = null
        Analytics.isEnabled = true
    }

    @Test fun readingEvents() {
        val opened = AnalyticsEvent.HymnOpened("english", 12, HymnSource.PlaylistAdvance)
        assertEquals("hymn_opened", opened.name)
        assertEquals(mapOf("hymnal" to "english", "hymn_number" to 12, "source" to "playlist_advance"), opened.properties)
        assertEquals(mapOf("from_hymnal" to "english", "to_hymnal" to "sdah", "source" to "church_mode"),
            AnalyticsEvent.HymnalSwitched("english", "sdah", HymnalSource.ChurchMode).properties)
        assertEquals(mapOf("surface" to "lectern", "scope" to "lyrics", "query_length" to 5, "result_count" to 2, "is_number" to false),
            AnalyticsEvent.SearchPerformed(SearchSurface.Lectern, SearchScope.Lyrics, 5, 2, false).properties)
        assertEquals("none", AnalyticsEvent.ReaderMenuOpened(null).properties["panel"])
        assertEquals(mapOf("tool" to "sheetMusic", "source" to "reader_menu"), AnalyticsEvent.ToolOpened(ExtraSheet.SheetMusic, ToolSource.ReaderMenu).properties)
    }

    @Test fun churchAppearanceAndPlayerEvents() {
        assertEquals(mapOf("duration_seconds" to 90, "verses_shown" to 8, "hymns_shown" to 2),
            AnalyticsEvent.ChurchModeExited(90, 8, 2).properties)
        assertEquals("service_plan", AnalyticsEvent.ChurchModeEntered(ChurchModeSource.ServicePlan).properties["source"])
        assertEquals(mapOf("setting" to "surface", "value" to "black"),
            AnalyticsEvent.AppearanceChanged(AppearanceChange.Surface(ReadingSurface.Black)).properties)
        assertEquals("alignment", AppearanceChange.Centered(true).setting)
        assertEquals("centered", AppearanceChange.Centered(true).value)
        assertEquals(mapOf("setting" to "repeat_chorus", "is_on" to true), AnalyticsEvent.SettingChanged(ToggleSetting.RepeatChorus, true).properties)
        assertEquals(mapOf("hymn_number" to 1, "tempo" to "medium", "resumed" to false), AnalyticsEvent.AccompanimentPlayed(1, resumed = false).properties)
        assertEquals("hymn_of_the_day", AnalyticsEvent.SheetMusicOpened(100, SheetMusicAccess.HymnOfTheDay).properties["access"])
    }

    @Test fun toolEvents() {
        assertEquals(mapOf("part" to "verse", "level" to "most", "word_count" to 12),
            AnalyticsEvent.MemoryGameStarted(MemoryPart.Verse, MemoryLevel.Most, 12).properties)
        assertEquals("next_level", AnalyticsEvent.MemoryRoundReplayed(MemoryPart.Chorus, MemoryLevel.Few, MemoryReplay.NextLevel).properties["reason"])
        assertEquals("key_chosen", AnalyticsEvent.PitchPipeUsed(PitchPipeAction.KeyChosen).properties["action"])
        // A passage page sends no hymn number or confidence.
        assertEquals(mapOf("hymnal" to "english", "book" to "JHN", "surface" to "passage"),
            AnalyticsEvent.ScriptureOpened("english", null, "JHN", null, ScriptureSurface.Passage).properties)
        assertEquals(5, AnalyticsEvent.ScriptureOpened("english", 1, "JHN", ScriptureConfidence.High, ScriptureSurface.AboutHymn).properties.size)
    }

    @Test fun everyEventNameIsIOSs() {
        val names = listOf(
            AnalyticsEvent.AppOpened(LaunchKind.Cold), AnalyticsEvent.AppBackgrounded(1),
            AnalyticsEvent.PlaylistCreated(1), AnalyticsEvent.PlaylistEdited(PlaylistEdit.Renamed, 1), AnalyticsEvent.PlaylistDeleted(1),
            AnalyticsEvent.PlaylistPlayed(1, 0), AnalyticsEvent.ServicePlanCreated(1), AnalyticsEvent.ServicePlanEdited(ServicePlanEdit.RoleSet, 1),
            AnalyticsEvent.ServicePlanDeleted(1), AnalyticsEvent.ServicePlanStarted(1), AnalyticsEvent.CollectionStarted(1),
            AnalyticsEvent.ChurchModeCastChanged(true, true), AnalyticsEvent.MirroringDetected(MirroringRoute.Capture, false),
            AnalyticsEvent.TextSizeChanged(TextSizeContext.ChurchMode, TextSizeMethod.Buttons, 42),
            AnalyticsEvent.AccompanimentTempoChanged(com.mDev.AdventPraise.settings.PlaybackTempo.Fast),
            AnalyticsEvent.FreePlayUsed(1, 4), AnalyticsEvent.PlayLimitPaywallShown(1), AnalyticsEvent.SheetMusicPaywallOpened(1),
            AnalyticsEvent.MemoryHintUsed(MemoryPart.Verse, MemoryLevel.All, 0), AnalyticsEvent.MemoryStreakReached(MemoryPart.Verse, MemoryLevel.All, 3),
            AnalyticsEvent.MemoryVerseLearned(MemoryPart.Verse, 3), AnalyticsEvent.FeatureBoardOpened(true),
            AnalyticsEvent.FeatureBoardDisclosureAccepted, AnalyticsEvent.FeatureBoardClosed(3, true), AnalyticsEvent.WhatsNewViewed("7.1"),
            AnalyticsEvent.WhatsNewDismissed("7.1", WhatsNewAction.Continue), AnalyticsEvent.TourStarted(TourSource.More),
            AnalyticsEvent.TourStepCompleted(2), AnalyticsEvent.TourFinished(true, 6), AnalyticsEvent.ShareOpened,
            AnalyticsEvent.ShareFinished(false, null), AnalyticsEvent.ExternalLinkOpened(ExternalLink.RateApp),
            AnalyticsEvent.IntentRun(IntentKind.NextHymn, true), AnalyticsEvent.ErrorOccurred(ErrorDomain.HymnalLoad, "x"),
        ).map { it.name }
        assertEquals(listOf(
            "app_opened", "app_backgrounded", "playlist_created", "playlist_edited", "playlist_deleted", "playlist_played",
            "service_plan_created", "service_plan_edited", "service_plan_deleted", "service_plan_started", "collection_started",
            "church_mode_cast_changed", "mirroring_detected", "text_size_changed", "accompaniment_tempo_changed",
            "free_play_used", "play_limit_paywall_shown", "sheet_music_paywall_opened", "memory_hint_used", "memory_streak_reached",
            "memory_verse_learned", "feature_board_opened", "feature_board_disclosure_accepted", "feature_board_closed",
            "whats_new_viewed", "whats_new_dismissed", "tour_started", "tour_step_completed", "tour_finished", "share_opened",
            "share_finished", "external_link_opened", "intent_run", "error_occurred",
        ), names)
        assertEquals(28, AnalyticsScreen.entries.size)
        assertEquals("number_pad", AnalyticsScreen.NumberPad.key)
    }

    @Test fun nothingIsSentWithUsageSharingOff() {
        val sent = mutableListOf<String>()
        Analytics.testSink = { sent += it.name }
        Analytics.track(AnalyticsEvent.ShareOpened)
        Analytics.isEnabled = false
        Analytics.track(AnalyticsEvent.ShareOpened)
        Analytics.error(ErrorDomain.Audio, "x")
        assertEquals(listOf("share_opened"), sent)
        Analytics.isEnabled = true
        Analytics.setHymnal("sdah")
        assertEquals("sdah", Analytics.superProperties["hymnal"])
        assertTrue(Analytics.PROJECT_TOKEN.startsWith("phc_"))
        assertEquals("https://eu.i.posthog.com", Analytics.HOST)
    }

    @Test fun featureBoardSlugs() {
        assertEquals("advent-praise", FeatureBoardConfig.slug(" advent-praise "))
        assertEquals(null, FeatureBoardConfig.slug("\$(FEATURES_VOTE_API_KEY)"))
        assertEquals(null, FeatureBoardConfig.slug("MyKlippa"))
        assertEquals(null, FeatureBoardConfig.slug(""))
        assertFalse(FeatureBoardConfig.isEnabled)
        assertEquals(mapOf("app_version" to "7.1", "platform" to "android"), FeatureBoardConfig.metadata("7.1"))
    }

    @Test fun jsonReadsAndWritesWhatTheAppKeeps() {
        val value = Json.parse("""{"a":[1,2.5,"x\né",true,null],"b":{"c":-3e2}}""") as Map<*, *>
        assertEquals(listOf(1L, 2.5, "x\né", true, null), value["a"])
        assertEquals(-300.0, (value["b"] as Map<*, *>)["c"])
        assertEquals("""{"k":["a\"b",1,2.5,false]}""", Json.write(mapOf("k" to listOf("a\"b", 1, 2.5, false))))
        assertEquals(null, Json.parseOrNull("{"))
    }
}
