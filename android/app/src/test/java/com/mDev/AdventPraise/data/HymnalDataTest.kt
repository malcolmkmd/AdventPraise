package com.mDev.AdventPraise.data

import com.mDev.AdventPraise.extras.HymnCollections
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The shared hymnal files, read as iOS reads them (SDAHymnalTests, SDAHReferenceTests). */
class HymnalDataTest {
    private val assets = DirectoryAssets.iosResources()
    private val catalogue = HymnalInfo.catalogue(assets)
    private val tunes = SdahTunes(assets)
    private val midi = MidiCatalog(assets, tunes)
    private val english = Hymnal.load(assets, HymnalInfo.default(catalogue), midi)!!
    private val sdahInfo = HymnalInfo.with(HymnalInfo.SDAH_ID, catalogue)!!
    private val sdah = Hymnal.load(assets, sdahInfo, midi)!!
    private val cross = CrossReference(english)

    @Test fun theCatalogueIsTheNineTranslationsAndTheSDAHymnal() {
        assertEquals(listOf("english", "chichewa", "tswana", "xhosa", "sotho", "shona", "venda", "zulu", "ndebele", "sdah"),
            catalogue.map { it.id })
        assertEquals(listOf("sdah"), catalogue.filter { it.isOwnBook }.map { it.id })
        assertEquals("SDA Hymnal (1985)", sdahInfo.name)
        assertEquals("English", sdahInfo.language)
        assertEquals("SDA Hymnal", sdahInfo.shortLabel)
        assertEquals("English", HymnalInfo.default(catalogue).shortLabel)
        assertEquals(Numbering.Sdah, sdahInfo.numbering)
        assertEquals(695, sdahInfo.maxNumber)
        // Every hymnal loads.
        for (info in catalogue) {
            val hymnal = Hymnal.load(assets, info, midi)
            assertNotNull(info.id, hymnal)
            assertEquals(info.id, info.hymnCount, hymnal!!.count)
        }
    }

    @Test fun everySDAHymnIsThereNumberedOneTo695() {
        assertEquals((1..695).toList(), sdah.hymns.map { it.number })
        assertTrue(sdah.hymns.all { it.title.isNotEmpty() && it.blocks.isNotEmpty() })
        assertEquals("Praise to the Lord", sdah.hymn(1)?.title)
        assertEquals("Great Is Thy Faithfulness", sdah.hymn(100)?.title)
        assertEquals("Praise God, From Whom All Blessings", sdah.hymn(695)?.title)
        assertNull(sdah.hymn(696))
        assertTrue(sdah.search("368", inLyrics = false).first().hymn.title.startsWith("Watchman"))
        assertEquals(126, sdah.search("bleak midwinter", inLyrics = true).first().hymn.number)
    }

    @Test fun referencesAreSortedAsOnIOS() {
        val first = english.hymn(1)!!
        assertEquals("Watchman Blow The Gospel Trumpet", first.title)
        assertEquals(listOf("AH 350", "SDAH 368"), first.references)
    }

    @Test fun crossReferencesMatchByHymnNotByNumber() {
        val shona = HymnalInfo.with("shona", catalogue)!!
        val en = english.info
        assertEquals(368, cross.number(1, en, sdahInfo))
        assertEquals(1, cross.number(368, sdahInfo, en))
        assertEquals(368, cross.number(1, shona, sdahInfo))
        assertNull(cross.number(71, en, sdahInfo))
        assertNull(cross.number(1, sdahInfo, en))
        assertEquals(12, cross.number(12, en, shona))
        // The SDA Hymnal's own "CIS n" refs agree with the English "SDAH n" ones.
        for (hymn in sdah.hymns) {
            val cis = hymn.references.firstOrNull { it.startsWith("CIS ") }?.removePrefix("CIS ")?.toIntOrNull()
            assertEquals("SDAH ${hymn.number}", cross.cisForSdah[hymn.number], cis)
        }
    }

    @Test fun accompanimentOnlyForTheSameTune() {
        assertNotNull(sdah.hymn(368)?.midiAsset)
        assertEquals(english.hymn(1)?.midiAsset, sdah.hymn(368)?.midiAsset)
        assertEquals("hymn-001.mid", english.hymn(1)?.midiAsset)
        assertNull(sdah.hymn(489)?.midiAsset)
        assertNull(sdah.hymn(1)?.midiAsset)
        assertNull(english.hymn(4)?.midiAsset) // no hymn-004.mid ships
    }

    @Test fun collectionsCoverTheWholeSDAHymnal() {
        val collections = HymnCollections(assets)
        assertEquals((1..695).toList(), collections.available("sdah").flatMap { it.numbers("sdah") }.sorted())
        assertEquals(1, collections.containing(368, "sdah").size)
        assertEquals("1–69", collections.all.first().sdahRange)
        assertTrue(collections.available("english").isNotEmpty())
        assertFalse(collections.available("english").any { it.numbers("english").isEmpty() })
    }

    @Test fun sungSequenceAndPlainText() {
        val h = Hymn(9, "T", emptyList(), listOf(Block.Chorus(listOf("c")), Block.Verse(1, listOf("a")), Block.Verse(2, listOf("b"))), null)
        assertEquals(listOf("c", "a", "c", "b", "c"), h.sungSequence.map { it.lines.first() })
        assertEquals("Refrain:\nc\n\n1.\na\n\n2.\nb", h.plainText("Refrain"))
    }

    @Test fun removedHymnalsMapToEnglishWhereNumberedAlike() {
        val removed = RemovedHymnals(english)
        assertTrue(RemovedHymnals.contains("tonga"))
        assertFalse(RemovedHymnals.contains("sdah"))
        assertEquals(12, removed.englishNumber(12, "tonga"))
        assertNull(removed.englishNumber(250, "kinyarwanda"))
        assertNull(removed.englishNumber(12, "swahili"))
        assertEquals("Sabbath · Tonga", RemovedHymnals.copyName("Sabbath", "tonga"))
    }
}
