package com.mDev.AdventPraise.ui.root

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.ui.about.AboutAppPage
import com.mDev.AdventPraise.ui.church.ChurchAnnouncementSheet
import com.mDev.AdventPraise.ui.church.ChurchImageSheet
import com.mDev.AdventPraise.ui.church.ChurchModeScreen
import com.mDev.AdventPraise.ui.church.ChurchSheetContainer
import com.mDev.AdventPraise.ui.church.ScreenMirroringHelpSheet
import com.mDev.AdventPraise.ui.design.AdventDrawer
import com.mDev.AdventPraise.ui.extras.CollectionHymnsPage
import com.mDev.AdventPraise.ui.extras.CollectionsPage
import com.mDev.AdventPraise.ui.extras.HymnCreditsPage
import com.mDev.AdventPraise.ui.extras.HymnScripturePage
import com.mDev.AdventPraise.ui.extras.HymnSourcesPage
import com.mDev.AdventPraise.ui.extras.HymnStoryPage
import com.mDev.AdventPraise.ui.extras.MemoriseScreen
import com.mDev.AdventPraise.ui.extras.PassageHymnsPage
import com.mDev.AdventPraise.ui.extras.ScriptureIndexPage
import com.mDev.AdventPraise.ui.extras.ServicePlanPage
import com.mDev.AdventPraise.ui.extras.ServicePlannerPage
import com.mDev.AdventPraise.ui.legal.LegalScreen
import com.mDev.AdventPraise.ui.library.HymnListScreen
import com.mDev.AdventPraise.ui.more.FeatureBoardSheet
import com.mDev.AdventPraise.ui.more.MoreScreen
import com.mDev.AdventPraise.ui.paywall.PaywallScreen
import com.mDev.AdventPraise.ui.pitchpipe.PitchPipeScreen
import com.mDev.AdventPraise.ui.playlists.PlaylistDeleteDialog
import com.mDev.AdventPraise.ui.playlists.PlaylistEditorSheet
import com.mDev.AdventPraise.ui.playlists.PlaylistNameDialog
import com.mDev.AdventPraise.ui.reader.AboutHymnRoot
import com.mDev.AdventPraise.ui.reader.HymnalsSheet
import com.mDev.AdventPraise.ui.sheetmusic.SheetMusicScreen
import com.mDev.AdventPraise.ui.support.SupportScreen
import com.mDev.AdventPraise.ui.support.TipThanksSheet
import com.mDev.AdventPraise.ui.tour.TourOverlay
import com.mDev.AdventPraise.ui.whatsnew.WhatsNewContent
import com.mDev.AdventPraise.ui.whatsnew.WhatsNewDrawerActions
import com.mDev.AdventPraise.ui.whatsnew.WhatsNewDrawerStyle

/**
 * One container on screen: a destination with the pages pushed inside it
 * (More's pages, About this hymn's), or a destination on its own.
 */
private data class Group(val key: String, val entries: List<Destination>) {
    val root: Destination get() = entries.first()
    val top: Destination get() = entries.last()
}

private fun groupKey(d: Destination): String = when {
    d == Destination.More || d.presentation == Presentation.MorePage -> "more"
    d is Destination.AboutHymn || d.presentation == Presentation.AboutHymnPage -> "about"
    else -> d.toString()
}

private fun groups(stack: List<Destination>): List<Group> {
    val out = mutableListOf<Group>()
    for (d in stack) {
        if (d.presentation == Presentation.Root) continue
        val key = groupKey(d)
        val last = out.lastOrNull()
        if (last != null && last.key == key) out[out.lastIndex] = last.copy(entries = last.entries + d)
        else out += Group(key, listOf(d))
    }
    return out
}

/**
 * Draws the navigator's stack over the reader, each destination in its iOS
 * presentation. A popped container stays until it has animated away.
 */
@Composable
fun PresentationHost(services: AppServices, navigator: AppNavigator) {
    val current = groups(navigator.stack)
    val currentKeys = current.map { it.key }
    val shown = remember { mutableStateMapOf<String, Group>() }
    val order = remember { mutableStateListOf<String>() }
    current.forEach { shown[it.key] = it }
    LaunchedEffect(currentKeys) {
        currentKeys.forEach { if (it !in order) order += it }
    }
    val rendered = order + currentKeys.filter { it !in order }
    rendered.forEach { k ->
        val group = shown[k] ?: return@forEach
        key(k) {
            GroupContainer(
                group = group,
                visible = k in currentKeys,
                services = services,
                navigator = navigator,
                onGone = { order.remove(k); if (k !in navigator.stack.map(::groupKey)) shown.remove(k) },
            )
        }
    }
}

@Composable
private fun GroupContainer(
    group: Group,
    visible: Boolean,
    services: AppServices,
    navigator: AppNavigator,
    onGone: () -> Unit,
) {
    val root = group.root
    val top = group.top
    when {
        group.key == "more" -> {
            // More's own root is the first-milestone screen until it moves into the stack;
            // then its pages push above it here.
            val hasRoot = root == Destination.More
            SheetContainer(
                title = top.title,
                visible = visible,
                onDismissRequest = { navigator.leaveMore() },
                onGone = onGone,
                onBack = if (group.entries.size > 1) ({ navigator.back() }) else null,
            ) {
                Pages(top) { page ->
                    if (page == Destination.More && hasRoot) MoreScreen(services)
                    else DestinationContent(page, services, navigator, onClose = { navigator.back() })
                }
            }
        }
        group.key == "about" -> AdventDrawer(
            title = root.title ?: "",
            onDismissRequest = { navigator.dismiss(root) },
            visible = visible,
            page = top.takeIf { it !is Destination.AboutHymn },
            pageTitle = top.takeIf { it !is Destination.AboutHymn }?.title,
            onBack = { navigator.back() },
            onDismissed = onGone,
        ) { page ->
            if (page == null) AboutHymnRoot(services, navigator, (root as? Destination.AboutHymn)?.source ?: "reader_menu")
            else DestinationContent(page as Destination, services, navigator, onClose = { navigator.back() })
        }
        root.presentation == Presentation.Drawer -> AdventDrawer(
            title = root.title ?: "",
            onDismissRequest = { navigator.dismiss(root) },
            visible = visible,
            style = if (root is Destination.WhatsNew) WhatsNewDrawerStyle else com.mDev.AdventPraise.ui.design.AdventDrawerStyle(),
            onDismissed = onGone,
            actions = if (root is Destination.WhatsNew) ({ WhatsNewDrawerActions(services, navigator) { navigator.dismiss(root) } }) else null,
        ) { DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) }) }
        // Church mode's sheets are always dark, with their own bars (church area).
        root.presentation == Presentation.ChurchSheet -> ChurchSheetContainer(
            visible = visible,
            onDismissRequest = { navigator.dismiss(root) },
            onGone = onGone,
        ) { DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) }) }
        root.presentation == Presentation.Sheet -> SheetContainer(
            title = root.title,
            visible = visible,
            onDismissRequest = { navigator.dismiss(root) },
            onGone = onGone,
            showsBar = root !is Destination.Paywall && root !is Destination.Support && root !is Destination.TipThanks,
        ) { DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) }) }
        root.presentation == Presentation.FullScreen -> FullScreenContainer(
            visible = visible,
            onDismissRequest = { navigator.dismiss(root) },
            onGone = onGone,
        ) { DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) }) }
        root.presentation == Presentation.Dialog -> DialogContainer(
            visible = visible,
            onDismissRequest = { navigator.dismiss(root) },
            onGone = onGone,
        ) { DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) }) }
        root.presentation == Presentation.Overlay -> {
            if (visible) DestinationContent(root, services, navigator, onClose = { navigator.dismiss(root) })
            LaunchedEffect(visible) { if (!visible) onGone() }
        }
        else -> LaunchedEffect(Unit) { onGone() }
    }
}

/** Pages sliding in over each other inside one container. */
@Composable
private fun Pages(top: Destination, content: @Composable (Destination) -> Unit) {
    AnimatedContent(
        targetState = top,
        transitionSpec = { (slideInHorizontally { it / 3 } + fadeIn()) togetherWith (slideOutHorizontally { -it / 3 } + fadeOut()) },
        label = "pages",
    ) { page -> Box(Modifier.fillMaxSize()) { content(page) } }
}

/**
 * Every destination's content, from the package of the area that owns it. The
 * containers (sheet, cover, drawer, dialog) are drawn around it by the host.
 */
@Composable
fun DestinationContent(destination: Destination, services: AppServices, navigator: AppNavigator, onClose: () -> Unit) {
    val scroll = @Composable { body: @Composable () -> Unit ->
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) { body() }
    }
    when (destination) {
        // Reader
        Destination.Reader -> Unit
        Destination.HymnList -> HymnListScreen(services)
        Destination.Hymnals -> HymnalsSheet(services, navigator)
        is Destination.AboutHymn -> AboutHymnRoot(services, navigator, destination.source)
        // Extras, inside About this hymn
        Destination.HymnStory -> HymnStoryPage(services, navigator)
        Destination.HymnCredits -> HymnCreditsPage(services, navigator)
        Destination.HymnSources -> HymnSourcesPage(services, navigator)
        Destination.HymnScripture -> HymnScripturePage(services, navigator)
        is Destination.HymnPassage -> PassageHymnsPage(services, navigator, destination.passageId, destination.reference)
        is Destination.HymnCollectionPage -> CollectionHymnsPage(services, navigator, destination.collectionId, destination.collectionTitle)
        Destination.HymnPitch -> PitchPipeScreen(services, navigator, null)
        // Music
        is Destination.SheetMusic -> SheetMusicScreen(services, navigator, destination.source, onClose)
        is Destination.PitchPipe -> PitchPipeScreen(services, navigator, destination.hymnNumber)
        // Church
        is Destination.ChurchMode -> ChurchModeScreen(services, navigator, destination.source, onClose)
        Destination.ChurchAnnouncement -> ChurchAnnouncementSheet(services, navigator)
        Destination.ChurchImage -> ChurchImageSheet(services, navigator)
        Destination.ScreenMirroringHelp -> ScreenMirroringHelpSheet(services, navigator)
        is Destination.PlaylistEditor -> PlaylistEditorSheet(services, navigator, destination.playlistId)
        is Destination.PlaylistName -> PlaylistNameDialog(services, navigator, destination.playlistId, onClose)
        is Destination.PlaylistDelete -> PlaylistDeleteDialog(services, navigator, destination.playlistId, onClose)
        // Extras
        is Destination.Memorise -> MemoriseScreen(services, navigator, destination.source)
        Destination.ScriptureIndex -> scroll { ScriptureIndexPage(services, navigator) }
        is Destination.Passage -> scroll { PassageHymnsPage(services, navigator, destination.passageId, destination.reference) }
        Destination.Collections -> scroll { CollectionsPage(services, navigator) }
        is Destination.Collection -> scroll { CollectionHymnsPage(services, navigator, destination.collectionId, destination.collectionTitle) }
        Destination.ServicePlanner -> scroll { ServicePlannerPage(services, navigator) }
        is Destination.ServicePlan -> scroll { ServicePlanPage(services, navigator, destination.planId) }
        // Shell
        Destination.More -> MoreScreen(services)
        is Destination.Paywall -> PaywallScreen(
            services,
            ProFeature.entries.firstOrNull { it.analyticsName == destination.feature } ?: ProFeature.Support,
            onClose,
        )
        Destination.Support -> SupportScreen(services, navigator, onClose)
        is Destination.TipThanks -> TipThanksSheet(services, navigator, destination.tipId, onClose)
        Destination.AboutApp -> scroll { AboutAppPage(services, navigator) }
        Destination.Privacy -> LegalScreen(LegalDocument.Privacy, onClose)
        Destination.Terms -> LegalScreen(LegalDocument.Terms, onClose)
        Destination.FeatureBoard -> FeatureBoardSheet(services, navigator)
        is Destination.WhatsNew -> WhatsNewContent(services, navigator)
        is Destination.Tour -> TourOverlay(services, navigator, destination.source, onClose)
    }
}
