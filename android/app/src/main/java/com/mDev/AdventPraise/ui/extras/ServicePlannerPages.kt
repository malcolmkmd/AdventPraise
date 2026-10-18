// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.CalendarToday
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.FilterNone
import androidx.compose.material.icons.rounded.FormatListNumbered
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.ServicePlan
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/*
 * Service plans for the open hymnal, and the editor for one plan, both pages
 * in More (ServicePlannerView.swift). The list leads with the next service;
 * the editor has one header (name and date), "Start in church mode", the
 * hymns in order (each with a role, a pitch pipe, and moves and removal in
 * its ••• menu) and an add-by-number field.
 */

/** The service planner: saved plans. A More page. */
@Composable
fun ServicePlannerPage(services: AppServices, navigator: AppNavigator) {
    val hymnal = services.reader.hymnal ?: return
    val hymn = services.reader.hymn ?: return
    val planner = services.planner
    ServicePlansContent(
        hymnal = hymnal,
        current = hymn,
        plans = planner.plans(hymnal.id),
        today = LocalDate.now(),
        onOpen = { navigator.openServicePlan(it.id) },
        onNew = { navigator.openServicePlan(planner.newPlan(hymnal.id, listOf(hymn.number)).id) },
        onStart = { plan ->
            val playable = plan.numbers.filter { hymnal.hymn(it) != null }
            ExtrasActions.startChurchMode(services, navigator, playable, plan.name, ExtrasActions.Queue.ServicePlan)
        },
        onDelete = { planner.delete(it) },
    )
    AnalyticsScreenEffect(AnalyticsScreen.ServicePlanner)
}

@Composable
fun ServicePlansContent(
    hymnal: Hymnal,
    current: Hymn,
    plans: List<ServicePlan>,
    today: LocalDate,
    onOpen: (ServicePlan) -> Unit,
    onNew: () -> Unit,
    onStart: (ServicePlan) -> Unit,
    onDelete: (ServicePlan) -> Unit,
) {
    val p = LocalSurface.current
    val sections = PlanSections.of(plans, today)
    val canStart = { plan: ServicePlan -> plan.numbers.any { hymnal.hymn(it) != null } }
    DrawerPageLayout(Modifier.padding(vertical = DS.Space.m)) {
        if (plans.isEmpty()) {
            PlansEmptyState(current, onNew)
        } else {
            sections.next?.let { next ->
                ExtrasGroup("Next service") {
                    PlanLink(
                        plan = next, canStart = canStart(next), onOpen = { onOpen(next) },
                        onStart = { onStart(next) }, onDelete = { onDelete(next) },
                        modifier = Modifier.background(p.tint.copy(alpha = DS.Fill.tintActive)),
                    ) { NextServiceCard(next, today) }
                }
            }
            ExtrasGroup { CreateButton(current, onNew) }
            DrawerNote("Plans list hymns from ${hymnal.name} in the order they’ll be sung.")
            PlanSection("Coming up", sections.comingUp, canStart, onOpen, onStart, onDelete)
            PlanSection("Past", sections.past, canStart, onOpen, onStart, onDelete)
        }
    }
}

@Composable
private fun PlanSection(
    title: String,
    plans: List<ServicePlan>,
    canStart: (ServicePlan) -> Boolean,
    onOpen: (ServicePlan) -> Unit,
    onStart: (ServicePlan) -> Unit,
    onDelete: (ServicePlan) -> Unit,
) {
    if (plans.isEmpty()) return
    ExtrasGroup(title) {
        plans.forEachIndexed { i, plan ->
            PlanLink(
                plan = plan, canStart = canStart(plan), isLast = i == plans.lastIndex,
                onOpen = { onOpen(plan) }, onStart = { onStart(plan) }, onDelete = { onDelete(plan) },
            ) { PlanRow(plan) }
        }
    }
}

@Composable
private fun CreateButton(current: Hymn, onNew: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.row)
            .clickable(role = Role.Button, onClick = onNew)
            .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Box(Modifier.size(DS.Size.numberTile).background(p.tint, CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Add, null, tint = p.onTint, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text("New service plan", style = DS.Type.label, color = p.tint)
            Text("Starts with hymn ${current.number}, ${current.title}", style = DS.Type.caption, color = p.secondary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun PlansEmptyState(current: Hymn, onNew: () -> Unit) {
    val p = LocalSurface.current
    Box(Modifier.fillMaxWidth().padding(vertical = DS.Space.l), contentAlignment = Alignment.Center) {
        Column(
            Modifier.widthIn(max = 360.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Box(Modifier.size(76.dp).background(p.tint.copy(alpha = DS.Fill.tintSelected), CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.FormatListNumbered, null, tint = p.tint, modifier = Modifier.size(36.dp))
            }
            Text("Plan this week’s service", style = DS.Type.sheetTitle, color = p.foreground, textAlign = TextAlign.Center)
            Text("List the hymns in the order they’ll be sung, then sing them in church mode.",
                style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
            GlassButton("New service plan", onNew, Modifier.padding(top = DS.Space.s), icon = Icons.Rounded.Add, fullWidth = true)
            Text("Starts with hymn ${current.number}, ${current.title}.", style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center)
        }
    }
}

/** A plan in the list as a row that leads on: its content, a chevron, a divider; touch and hold for actions. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PlanLink(
    plan: ServicePlan,
    canStart: Boolean,
    onOpen: () -> Unit,
    onStart: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    isLast: Boolean = true,
    content: @Composable () -> Unit,
) {
    val p = LocalSurface.current
    var menu by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = DS.Size.row)
                .combinedClickable(role = Role.Button, onLongClick = { menu = true }, onClick = onOpen)
                .semantics { customActions = listOf(CustomAccessibilityAction("Delete") { onDelete(); true }) }
                .padding(horizontal = DS.Space.m, vertical = DS.Space.xxs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Box(Modifier.weight(1f)) { content() }
            Icon(Icons.Rounded.ChevronRight, null, tint = p.secondary, modifier = Modifier.size(24.dp))
        }
        if (!isLast) RowDivider(Modifier.align(Alignment.BottomStart))
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            MenuItem("Start in church mode", Icons.Rounded.FilterNone, enabled = canStart) { menu = false; onStart() }
            MenuItem("Delete", Icons.Rounded.Delete, destructive = true) { menu = false; onDelete() }
        }
    }
}

@Composable
private fun MenuItem(title: String, icon: ImageVector?, enabled: Boolean = true, destructive: Boolean = false, checked: Boolean = false, onClick: () -> Unit) {
    val p = LocalSurface.current
    val color = if (destructive) DS.Palette.destructive else p.foreground
    DropdownMenuItem(
        text = { Text(title, style = DS.Type.body, color = color) },
        onClick = onClick,
        enabled = enabled,
        leadingIcon = if (checked) ({ Icon(Icons.Rounded.Check, null, tint = p.tint) }) else if (icon == null) ({ Spacer(Modifier.size(24.dp)) }) else null,
        trailingIcon = icon?.let { { Icon(it, null, tint = color) } },
    )
}

/** The coming service, large: when, what, and the hymn numbers. */
@Composable
private fun NextServiceCard(plan: ServicePlan, today: LocalDate) {
    val p = LocalSurface.current
    val relative = PlanText.relativeDay(plan, today)
    val date = PlanText.dateText(plan)
    Column(
        Modifier.padding(vertical = DS.Space.s).clearAndSetSemantics {
            contentDescription = "Next service: ${plan.name}, ${date.orEmpty()}. ${PlanText.hymnSummary(plan)}"
        },
        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Eyebrow(relative ?: date ?: "No date", p.tint)
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text(plan.name, style = DS.Type.sheetTitle, color = p.foreground)
            if (relative != null && date != null) Text(date, style = DS.Type.detail, color = p.secondary)
        }
        if (plan.items.isEmpty()) {
            Text("No hymns yet", style = DS.Type.detail, color = p.secondary)
        } else {
            HymnNumberChips(plan.numbers)
        }
    }
}

/** Up to five hymn numbers as brass tiles, then "+N". */
@Composable
private fun HymnNumberChips(numbers: List<Int>) {
    val p = LocalSurface.current
    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.xs), verticalAlignment = Alignment.CenterVertically) {
        numbers.take(5).forEach { number ->
            Box(
                Modifier
                    .defaultMinSize(DS.Size.numberTile, DS.Size.numberTile)
                    .background(p.brass.copy(alpha = DS.Fill.tintSelected), dsShape(DS.Radius.badge))
                    .padding(horizontal = DS.Space.xs),
                contentAlignment = Alignment.Center,
            ) {
                Text(number.toString(), style = DS.Type.numeral.copy(fontFeatureSettings = "tnum"), color = p.brass, maxLines = 1)
            }
        }
        if (numbers.size > 5) Text("+${numbers.size - 5}", style = DS.Type.label, color = p.secondary)
    }
}

/** A plan in the list: a calendar tile, the name, and its hymns. */
@Composable
private fun PlanRow(plan: ServicePlan) {
    val p = LocalSurface.current
    Row(
        Modifier.padding(vertical = DS.Space.xxs).clearAndSetSemantics {
            contentDescription = "${plan.name}, ${PlanText.dateText(plan).orEmpty()}. ${PlanText.hymnSummary(plan)}"
        },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Column(
            Modifier.size(44.dp).background(p.tint.copy(alpha = DS.Fill.tintActive), dsShape(DS.Radius.badge)),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            val date = plan.date
            if (date != null) {
                Eyebrow(PlanText.monthAbbreviation(date), p.tint, tracking = 0.6f)
                Text(date.dayOfMonth.toString(), style = DS.Type.numeral.copy(fontFeatureSettings = "tnum", lineHeight = DS.Type.numeral.fontSize), color = p.foreground)
            } else {
                Icon(Icons.Rounded.CalendarToday, null, tint = p.secondary, modifier = Modifier.size(20.dp))
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text(plan.name, style = DS.Type.rowTitle, color = p.foreground, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(PlanText.hymnSummary(plan), style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

// MARK: - Plan editor

/** One service plan: its hymns, roles and date; Start runs it in church mode. A More page. */
@Composable
fun ServicePlanPage(services: AppServices, navigator: AppNavigator, planId: String) {
    val hymnal = services.reader.hymnal ?: return
    val hymn = services.reader.hymn ?: return
    val editor = remember(planId, hymnal.id) { ServicePlanEditor(services.planner, planId, hymnal) }
    ServicePlanContent(
        editor = editor,
        hymnal = hymnal,
        current = hymn,
        today = LocalDate.now(),
        onStart = { plan ->
            ExtrasActions.startChurchMode(services, navigator, editor.playable, plan.name, ExtrasActions.Queue.ServicePlan)
        },
        onOpenHymn = { navigator.openHymn(it, HymnSource.ServicePlan.key) },
        onPitch = { navigator.openPitchPipe(it) },
    )
    AnalyticsScreenEffect(AnalyticsScreen.ServicePlan)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServicePlanContent(
    editor: ServicePlanEditor,
    hymnal: Hymnal,
    current: Hymn,
    today: LocalDate,
    onStart: (ServicePlan) -> Unit,
    onOpenHymn: (Int) -> Unit,
    onPitch: (Int) -> Unit,
) {
    val p = LocalSurface.current
    val plan = editor.plan
    if (plan == null) {
        DrawerPageLayout(Modifier.padding(vertical = DS.Space.m)) { DrawerNote("This plan no longer exists.") }
        return
    }
    var pickingDate by rememberSaveable { mutableStateOf(false) }
    val playable = editor.playable
    DrawerPageLayout(Modifier.padding(vertical = DS.Space.m)) {
        // Header: name and date.
        Column(Modifier.padding(horizontal = DS.Space.xxs), verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            Box {
                if (plan.name.isEmpty()) Text("Plan name", style = DS.Type.hymnTitle, color = p.secondary)
                BasicTextField(
                    value = plan.name,
                    onValueChange = editor::setName,
                    textStyle = DS.Type.hymnTitle.copy(color = p.foreground),
                    cursorBrush = SolidColor(p.tint),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Plan name" },
                )
            }
            DateButton(plan, today) { pickingDate = true }
        }
        // Start in church mode.
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
            GlassButton(
                "Start in church mode", { onStart(plan) },
                Modifier.semantics { if (playable.isEmpty()) contentDescription = "Start in church mode. Add a hymn first." },
                icon = Icons.Rounded.FilterNone, fullWidth = true, enabled = playable.isNotEmpty(),
            )
            if (playable.isEmpty()) {
                Text(
                    if (plan.items.isEmpty()) "Add a hymn to start church mode." else "None of these hymns are in ${hymnal.name}.",
                    style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center,
                )
            }
        }
        // The hymns.
        if (plan.items.isEmpty()) {
            EmptyHymns()
        } else {
            ExtrasGroup(hymnCount(plan.items.size)) {
                plan.items.forEachIndexed { i, item ->
                    Box {
                        PlanHymnRow(
                            hymnal = hymnal, item = item,
                            canMoveUp = i > 0, canMoveDown = i < plan.items.lastIndex,
                            onRole = { editor.setRole(item.id, it) },
                            onOpen = { onOpenHymn(item.number) },
                            onPitch = { onPitch(item.number) },
                            onMove = { editor.move(item.id, it) },
                            onRemove = { editor.remove(item.id) },
                        )
                        if (i != plan.items.lastIndex) RowDivider(Modifier.align(Alignment.BottomStart), inset = 64.dp)
                    }
                }
            }
            if (plan.items.size > 1) DrawerNote("To reorder or remove a hymn, use its ••• menu.")
        }
        // Add hymns.
        ExtrasGroup("Add hymns") {
            if (editor.offersCurrent(current.number)) {
                Box {
                    AddRow(current) { editor.addCurrent(current.number) }
                    RowDivider(Modifier.align(Alignment.BottomStart), inset = 64.dp)
                }
            }
            NumberField(editor)
        }
    }
    if (pickingDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = (plan.date ?: today).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = {
                TextButton({
                    state.selectedDateMillis?.let { editor.setDate(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
                    pickingDate = false
                }) { Text("Done", style = DS.Type.label, color = p.tint) }
            },
            dismissButton = { TextButton({ pickingDate = false }) { Text("Cancel", style = DS.Type.label, color = p.tint) } },
        ) { DatePicker(state, title = null, showModeToggle = false) }
    }
}

@Composable
private fun DateButton(plan: ServicePlan, today: LocalDate, onClick: () -> Unit) {
    val p = LocalSurface.current
    val date = PlanText.dateText(plan)
    val relative = PlanText.relativeDay(plan, today)
    Row(
        Modifier
            .heightIn(min = 36.dp)
            .clip(CircleShape)
            .background(p.tint.copy(alpha = DS.Fill.tintActive))
            .clickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Date, ${date ?: "none"}. Changes the date."
                role = Role.Button
            }
            .padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        Icon(Icons.Rounded.CalendarToday, null, tint = p.tint, modifier = Modifier.size(16.dp))
        Text(date ?: "Add a date", style = DS.Type.label, color = p.tint)
        if (relative != null) Text("· $relative", style = DS.Type.label, color = p.secondary)
        Icon(Icons.Rounded.ExpandMore, null, tint = p.secondary, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun EmptyHymns() {
    val p = LocalSurface.current
    Column(
        Modifier.fillMaxWidth().padding(vertical = DS.Space.m).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Box(Modifier.size(56.dp).background(p.brass.copy(alpha = DS.Fill.tintSelected), CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.AutoMirrored.Rounded.QueueMusic, null, tint = p.brass, modifier = Modifier.size(26.dp))
        }
        Text("No hymns yet", style = DS.Type.panelTitle, color = p.foreground)
        Text("Add the hymns in the order they’ll be sung, by number or from the hymn you’re reading.",
            style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
    }
}

/** One hymn of the plan: number tile, role, title, and its ••• options. */
@Composable
private fun PlanHymnRow(
    hymnal: Hymnal,
    item: ServicePlan.Item,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onRole: (String?) -> Unit,
    onOpen: () -> Unit,
    onPitch: () -> Unit,
    onMove: (Int) -> Unit,
    onRemove: () -> Unit,
) {
    val p = LocalSurface.current
    val title = hymnal.hymn(item.number)?.title
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.row)
            .semantics(mergeDescendants = true) {
                customActions = buildList {
                    if (canMoveUp) add(CustomAccessibilityAction("Move up") { onMove(-1); true })
                    if (canMoveDown) add(CustomAccessibilityAction("Move down") { onMove(1); true })
                    add(CustomAccessibilityAction("Remove") { onRemove(); true })
                }
            }
            .padding(start = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        PlanNumberTile(item.number.toString())
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            item.role?.let { Eyebrow(it, p.tint, tracking = 0.8f) }
            Text(
                title ?: "Not in ${hymnal.name}", style = DS.Type.rowTitle,
                color = if (title == null) p.secondary else p.foreground, maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
        Box {
            Box(
                Modifier
                    .size(DS.Size.hitTarget)
                    .clip(CircleShape)
                    .clickable(role = Role.Button) { menu = true }
                    .semantics { contentDescription = "Options for hymn ${item.number}" },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.MoreHoriz, null, tint = p.secondary) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                Text("Role", style = DS.Type.caption, color = p.secondary, modifier = Modifier.padding(horizontal = DS.Space.m, vertical = DS.Space.xxs))
                MenuItem("None", null, checked = item.role == null) { menu = false; onRole(null) }
                ServicePlanner.ROLES.forEach { role ->
                    MenuItem(role, null, checked = item.role == role) { menu = false; onRole(role) }
                }
                if (title != null) {
                    HorizontalDivider()
                    MenuItem("Open in reader", Icons.AutoMirrored.Rounded.MenuBook) { menu = false; onOpen() }
                    MenuItem("Pitch pipe", Icons.Rounded.MusicNote) { menu = false; onPitch() }
                }
                HorizontalDivider()
                MenuItem("Move up", Icons.Rounded.ArrowUpward, enabled = canMoveUp) { menu = false; onMove(-1) }
                MenuItem("Move down", Icons.Rounded.ArrowDownward, enabled = canMoveDown) { menu = false; onMove(1) }
                MenuItem("Remove", Icons.Rounded.Delete, destructive = true) { menu = false; onRemove() }
            }
        }
    }
}

/** "The hymn you're reading" suggestion in the Add hymns section. */
@Composable
private fun AddRow(current: Hymn, onAdd: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .clickable(onClick = onAdd)
            .clearAndSetSemantics {
                contentDescription = "Add hymn ${current.number}, ${current.title}"
                role = Role.Button
            }
            .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        PlanNumberTile(current.number.toString())
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text("The hymn you’re reading", style = DS.Type.caption, color = p.secondary)
            Text(current.title, style = DS.Type.rowTitle, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Icon(Icons.Rounded.AddCircle, null, tint = p.tint, modifier = Modifier.size(28.dp))
    }
}

@Composable
private fun NumberField(editor: ServicePlanEditor) {
    val p = LocalSurface.current
    val caption = editor.typedCaption
    val canAdd = editor.canAddTyped
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        PlanNumberTile("#", isPlaceholder = true)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Box {
                if (editor.numberText.isEmpty()) Text("Add by number", style = DS.Type.rowTitle.copy(fontWeight = FontWeight.Normal), color = p.secondary)
                BasicTextField(
                    value = editor.numberText,
                    onValueChange = editor::setNumber,
                    singleLine = true,
                    textStyle = DS.Type.rowTitle.copy(color = p.foreground),
                    cursorBrush = SolidColor(p.tint),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { editor.addTypedNumber() }),
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Add by number" },
                )
            }
            if (caption != null) Text(caption, style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Box(
            Modifier
                .size(DS.Size.hitTarget)
                .clip(CircleShape)
                .clickable(enabled = canAdd, role = Role.Button) { editor.addTypedNumber() }
                .semantics { contentDescription = "Add" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.AddCircle, null, tint = if (canAdd) p.tint else p.foreground.copy(alpha = 0.3f), modifier = Modifier.size(28.dp))
        }
    }
}

/** A hymn number in a brass tile, as in HymnRow; "#" as a placeholder. */
@Composable
private fun PlanNumberTile(text: String, isPlaceholder: Boolean = false) {
    val p = LocalSurface.current
    Box(
        Modifier
            .defaultMinSize(DS.Size.numberTile, DS.Size.numberTile)
            .background(if (isPlaceholder) p.primary(DS.Fill.inset) else p.brass.copy(alpha = DS.Fill.tintSelected), dsShape(DS.Radius.badge))
            .padding(horizontal = DS.Space.xxs)
            .then(if (isPlaceholder) Modifier.clearAndSetSemantics {} else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = DS.Type.numeral.copy(fontFeatureSettings = "tnum"), color = if (isPlaceholder) p.secondary else p.brass, maxLines = 1)
    }
}
