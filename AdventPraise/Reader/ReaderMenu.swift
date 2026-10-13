//
//  ReaderMenu.swift
//  Advent Praise
//
//  The reader menu: the globe at the top of the reader grows into a glass
//  bar holding the hymn's settings, and its panels unfold downward out of
//  the bar, as the Lectern's unfold upward at the bottom.
//
//         [ 🌐 English | ◐ Theme | Aa Text | ⓘ About ]   [ ✕ ]
//         ┌──────────────── panel ────────────────┐
//
//  Translation lists the hymnals ("Hymn N in…"). Theme is the reading
//  surface, Text the size, font, print, spacing and alignment; both preview
//  live on the lyrics. About is the hymn's story, scripture, collections and
//  accompaniment credit (ReaderMenuPanels.swift).
//
//  Geometry: the navigation bar keeps an empty slot where the globe sits
//  (`ReaderMenuGlobeSlot`), so the compact header still leaves room for it.
//  The globe itself is drawn by `ReaderMenuOverlay`, which RootView lays over
//  the whole window, above the navigation bar. With globe and bar in one
//  hierarchy, the bar can stay laid out where it opens (hidden while closed)
//  and only its glass and clip move: one animatable shape goes from the
//  globe's circle to the bar in a single transaction, the Lectern's spring
//  (`ReaderModel.setMenu`), and matchedGeometryEffect carries the globe
//  glyph to the Translation tab. Under Reduce Motion the globe and the bar
//  cross-fade in place.
//
//  Glass: iOS 26 draws it inside a GlassEffectContainer, one shape that
//  reshapes, as the Lectern does (see BARANIM_STATUS: glassEffectID moved
//  the content's clip out of step with a single shape). iOS 17–25: the globe
//  is a plain bar icon, and material fades in behind the bar.
//

import SwiftUI

// MARK: - Toolbar slot

/// Holds the globe's place in the navigation bar and reports where it is.
/// It draws nothing; ReaderMenuOverlay draws the globe on top of it.
struct ReaderMenuGlobeSlot: ToolbarContent {
    let model: ReaderModel

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) { slot }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { slot }
        }
    }

    private var slot: some View {
        Color.clear
            .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                // A first fix lands at once; later moves (rotation, the iPad
                // sidebar) glide, as the bar they belong to does.
                if model.menuAnchor.globe == .zero {
                    model.menuAnchor.globe = frame
                } else {
                    withAnimation(.smooth(duration: 0.35)) { model.menuAnchor.globe = frame }
                }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// The reader reports its frame, so the menu stays over it (iPad: the
    /// detail column, clear of the sidebar).
    func readerMenuArea(_ model: ReaderModel) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.menuAnchor.reader = $0 }
    }

    /// The globe and the menu it opens. Attach once, to the root, so it draws
    /// above the navigation bar and below the drawers and sheets.
    func readerMenu(_ model: ReaderModel) -> some View {
        overlay { ReaderMenuOverlay(model: model) }
    }
}

// MARK: - Overlay

private struct ReaderMenuOverlay: View {
    let model: ReaderModel
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var menu

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            if let geometry = MenuGeometry(anchor: model.menuAnchor, in: frame) {
                ZStack(alignment: .topLeading) {
                    if model.isMenuOpen {
                        backdrop.transition(.opacity)
                    }
                    if reduceMotion {
                        // No morph: the globe and the bar cross-fade in place,
                        // each at its own size.
                        if model.isMenuOpen {
                            morph(geometry, open: true).id("open").transition(.opacity)
                        } else {
                            morph(geometry, open: false).id("closed").transition(.opacity)
                        }
                    } else {
                        morph(geometry, open: model.isMenuOpen)
                    }
                }
            }
        }
        .ignoresSafeArea()
        // The globe goes with the rest of the chrome in focus mode.
        .opacity(model.isFocused ? 0 : 1)
        .allowsHitTesting(!model.isFocused)
        .accessibilityHidden(model.isFocused)
        .animation(DS.Motion.adaptive(DS.Motion.focus, reduceMotion: reduceMotion), value: model.isFocused)
    }

    /// A light dim that closes the menu when tapped. The lyrics stay readable
    /// beneath it, so Theme and Text changes can be judged as they're made.
    private var backdrop: some View {
        Color.black.opacity(surface.isDark ? 0.24 : 0.07)
            .contentShape(Rectangle())
            .onTapGesture { model.closeMenu() }
            .accessibilityHidden(true)
    }

    /// The bar is always laid out where it opens, hidden while closed; only
    /// the glass and its clip move, from the globe's circle to the bar's
    /// shape. Nothing is inserted, so nothing slides: the glass uncovers the
    /// bar from the globe outward, the close button lands where the globe
    /// was, and the globe glyph flies to the Translation tab.
    private func morph(_ geometry: MenuGeometry, open: Bool) -> some View {
        let shape = MenuMorphShape(progress: open ? 1 : 0, closedSize: geometry.chip.size,
                                   inset: geometry.inset)
        return ZStack(alignment: .topTrailing) {
            ReaderMenuBar(model: model, namespace: menu, isOpen: open, heroGlobe: !reduceMotion,
                          panelMaxHeight: geometry.panelMaxHeight)
                .opacity(open ? 1 : 0)
                .allowsHitTesting(open)
                .accessibilityHidden(!open)
            if !open {
                globe(geometry)
                    .padding([.top, .trailing], geometry.inset)
                    .transition(.opacity)
            }
        }
        .frame(width: geometry.barWidth)
        .clipShape(shape)
        .modifier(MenuGlass(shape: shape, isOpen: open))
        // Closed, only the globe's circle takes touches, not the hidden bar.
        .contentShape(shape)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .offset(x: geometry.barX, y: geometry.barY)
    }

    private func globe(_ geometry: MenuGeometry) -> some View {
        Button { model.openMenu() } label: {
            Image(systemName: "globe")
                .font(.system(size: 17, weight: .medium))
                .matchedGeometryEffect(id: reduceMotion ? "globe.chip" : "globe", in: menu,
                                       isSource: !model.isMenuOpen)
                .frame(width: geometry.chip.width, height: geometry.chip.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(globeColor)
        .accessibilityLabel("Reading options")
        .accessibilityValue("\(model.hymnalInfo.language), \(model.hymnalInfo.name)")
        .accessibilityHint("Switch translation, change the theme or text, or read about this hymn.")
        #if DEBUG
        .task {
            // After the globe has been on screen, so opening morphs from it.
            guard DebugLaunch.showsTranslations || DebugLaunch.menu != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            if DebugLaunch.showsTranslations { model.openMenu(.translation) }
            if let panel = DebugLaunch.menu { model.openMenu(panel.panel) }
        }
        #endif
    }

    /// iOS 26: ink on glass, like the bar's other buttons. Earlier: the bar's tint.
    private var globeColor: Color {
        if #available(iOS 26, *) { return .primary }
        return surface.tint
    }
}

/// Where the globe and the bar sit, in the overlay's coordinates.
private struct MenuGeometry {
    static let rowHeight: CGFloat = 52
    /// Clear of the window or column edge on the leading side.
    private static let margin: CGFloat = 12
    /// What the menu leaves visible below it: a look at the lyrics and the Lectern.
    private static let bottomClearance: CGFloat = 132

    let chip: CGRect
    /// The globe sits this far inside the bar's top trailing corner.
    var inset: CGFloat { (Self.rowHeight - chip.height) / 2 }
    let barX: CGFloat
    let barY: CGFloat
    let barWidth: CGFloat
    let panelMaxHeight: CGFloat

    /// Nil until the slot has been measured.
    init?(anchor: ReaderMenuAnchor, in frame: CGRect) {
        guard anchor.globe.width > 0 else { return nil }
        chip = anchor.globe.offsetBy(dx: -frame.minX, dy: -frame.minY)
        let reader = anchor.reader.width > 0
            ? anchor.reader.offsetBy(dx: -frame.minX, dy: -frame.minY)
            : CGRect(origin: .zero, size: frame.size)
        // The close button lands where the globe was: the bar's trailing edge
        // sits half the row's extra height beyond the globe's.
        let trailing = chip.maxX + (Self.rowHeight - chip.height) / 2
        barWidth = max(min(DS.Space.lecternMaxWidth, trailing - reader.minX - Self.margin), chip.width)
        barX = trailing - barWidth
        barY = chip.midY - Self.rowHeight / 2
        panelMaxHeight = max(reader.maxY - (barY + Self.rowHeight) - Self.bottomClearance, 180)
    }
}

/// The globe's circle at `progress` 0, the whole bar (and its panel) at 1.
/// The closed circle sits `inset` inside the top trailing corner; corners
/// go from the circle's radius to the row's.
private struct MenuMorphShape: Shape {
    var progress: CGFloat
    let closedSize: CGSize
    let inset: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let closed = CGRect(x: rect.maxX - inset - closedSize.width, y: rect.minY + inset,
                            width: closedSize.width, height: closedSize.height)
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        let shape = CGRect(x: mix(closed.minX, rect.minX), y: mix(closed.minY, rect.minY),
                           width: mix(closed.width, rect.width), height: mix(closed.height, rect.height))
        let radius = mix(closedSize.height / 2, MenuGeometry.rowHeight / 2)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: shape)
    }
}

/// iOS 26: Liquid Glass, interactive, reshaping inside its container. iOS
/// 17–25: the closed globe is a bare icon, as bar buttons are there; the
/// bar's material (opaque under Reduce Transparency) fades in as it opens.
private struct MenuGlass: ViewModifier {
    let shape: MenuMorphShape
    let isOpen: Bool
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content
                    .environment(\.dsOnGlass, true)
                    .glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .environment(\.dsOnGlass, true)
                .background {
                    ZStack {
                        if reduceTransparency { shape.fill(surface.elevated) } else { shape.fill(.thinMaterial) }
                        shape.stroke(surface.isDark ? Color.white.opacity(DS.Fill.stroke)
                                                    : Color.black.opacity(DS.Fill.hairline), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(surface.isDark ? 0.45 : 0.12), radius: 16, y: 6)
                    .opacity(isOpen ? 1 : 0)
                }
        }
    }
}

// MARK: - Bar

/// The open menu: the row of tabs and a close button, and the open tab's
/// panel unfolding beneath it.
private struct ReaderMenuBar: View {
    let model: ReaderModel
    let namespace: Namespace.ID
    /// Closed, the bar stays laid out under the globe, hidden.
    let isOpen: Bool
    /// The globe glyph flies to the Translation tab (off under Reduce Motion).
    let heroGlobe: Bool
    let panelMaxHeight: CGFloat
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedTab: ReaderMenuPanel?

    var body: some View {
        VStack(spacing: 0) {
            row
                .overlay(alignment: .bottom) { Divider().opacity(model.menuPanel == nil ? 0 : 0.6) }
            // Panels unfold from the row: out of its lower edge, fading,
            // while the glass grows around them. The slot clips, so a panel
            // sliding in or out never crosses the row.
            VStack(spacing: 0) {
                if let panel = model.menuPanel {
                    ReaderMenuPanelContent(model: model, panel: panel, maxHeight: panelMaxHeight)
                        .id(panel)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isOpen ? .isModal : [])
        .accessibilityAction(.escape) { model.closeMenu() }
        .onChange(of: isOpen) { _, open in
            // VoiceOver lands on the open tab, not back at the top of the screen.
            if open { focusedTab = model.menuPanel ?? .translation }
        }
    }

    private var row: some View {
        HStack(spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.xxs) {
                MenuTab(title: Text(model.hymnalInfo.language), isOn: model.menuPanel == .translation,
                        selection: selection(.translation)) {
                    Image(systemName: "globe")
                        .matchedGeometryEffect(id: heroGlobe ? "globe" : "globe.tab", in: namespace,
                                               isSource: isOpen)
                } action: { model.toggleMenuPanel(.translation) }
                    .accessibilityLabel("Translation")
                    .accessibilityValue("\(model.hymnalInfo.language), \(model.hymnalInfo.name)")
                    .accessibilityFocused($focusedTab, equals: .translation)
                MenuTab(title: Text("Theme"), isOn: model.menuPanel == .theme, selection: selection(.theme)) {
                    Image(systemName: "circle.lefthalf.filled")
                } action: { model.toggleMenuPanel(.theme) }
                    .accessibilityLabel("Theme")
                    .accessibilityValue(Text(settings.surface.name))
                    .accessibilityFocused($focusedTab, equals: .theme)
                MenuTab(title: Text("Text"), isOn: model.menuPanel == .text, selection: selection(.text)) {
                    Image(systemName: "textformat.size")
                } action: { model.toggleMenuPanel(.text) }
                    .accessibilityLabel("Text size and font")
                    .accessibilityValue(Text("\(Text(settings.style.font.name)), \(Int(settings.style.basePointSize)) points"))
                    .accessibilityFocused($focusedTab, equals: .text)
                MenuTab(title: Text("About"), isOn: model.menuPanel == .about, selection: selection(.about)) {
                    Image(systemName: "info.circle")
                } action: { model.toggleMenuPanel(.about) }
                    .accessibilityLabel("About this hymn")
                    .accessibilityFocused($focusedTab, equals: .about)
            }
            // The bar is a fixed 52 pt; the tabs' captions stop growing before
            // they'd need more. Panels below follow Dynamic Type further.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            closeButton
        }
        .padding(.leading, DS.Space.xs)
        .padding(.trailing, (MenuGeometry.rowHeight - DS.Size.hitTarget) / 2)
        .frame(height: MenuGeometry.rowHeight)
    }

    /// Where the globe was, so the same spot opens and closes the menu.
    private var closeButton: some View {
        Button { model.closeMenu() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background(Circle().fill(Color.primary.opacity(DS.Fill.inset)))
                .contentShape(Circle())
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(.primary)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close")
        .accessibilityHint("Closes reading options")
    }

    /// The open tab's highlight slides between tabs; under Reduce Motion each
    /// tab has its own, which fades in place.
    private func selection(_ panel: ReaderMenuPanel) -> MenuSelection {
        MenuSelection(id: reduceMotion ? "menu.on.\(panel.rawValue)" : "menu.on", namespace: namespace)
    }
}

private struct MenuSelection {
    let id: String
    let namespace: Namespace.ID
}

/// A tab: its glyph over a short caption, and a tint wash while its panel shows.
private struct MenuTab<Icon: View>: View {
    let title: Text
    let isOn: Bool
    let selection: MenuSelection
    @ViewBuilder let icon: Icon
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Space.hair) {
                icon.font(.system(size: 17, weight: .semibold)).frame(height: 22)
                title
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
            .background {
                if isOn {
                    RoundedRectangle.ds(DS.Radius.key)
                        .fill(surface.tint.opacity(DS.Fill.tintOn))
                        .matchedGeometryEffect(id: selection.id, in: selection.namespace)
                }
            }
            .contentShape(RoundedRectangle.ds(DS.Radius.key))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(isOn ? surface.tint : .primary)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
