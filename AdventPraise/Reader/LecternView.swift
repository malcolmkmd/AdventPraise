//
//  LecternView.swift
//  Advent Praise
//
//  The Lectern is ReaderToolbar: one floating glass capsule. Panels for the
//  hymn tray, number pad, word search, library, hymnals and More unfold
//  upward out of the same glass. On iPad the number pad is a popover and
//  the library button opens the sidebar.
//

import SwiftUI
import StoreKit

struct LecternView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ReadingSettings.self) private var settings
    @Environment(PurchaseStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var showPad = false

    private var toolbarPanel: ReaderToolbarPanel {
        switch model.lectern {
        case .collapsed: .none
        case .pad, .search: .jump
        case .library: .library
        case .hymn, .hymnals, .more: .hymn
        }
    }

    var body: some View {
        ReaderToolbar(
            number: model.hymn.id,
            title: model.hymn.title,
            status: statusLine,
            isPlaying: player.isPlaying && player.hymn?.id == model.hymn.id,
            hasAccompaniment: model.hymn.hasAccompaniment,
            openPanel: toolbarPanel,
            onPlay: { player.toggle(); Haptics.light() },
            onHymn: { hymnFamily ? model.closeLectern() : model.openLectern(.hymn) },
            onJump: { jumpTapped() },
            onLibrary: { libraryTapped() },
            onDismiss: { model.closeLectern() }
        ) {
            panel
        }
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: model.lectern)
        .animation(DS.Motion.adaptive(DS.Motion.lectern, reduceMotion: reduceMotion), value: model.libraryTab)
        .onChange(of: model.lectern) { _, state in searchFocused = (state == .search) }
        .popover(isPresented: $showPad, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            // The popover is the chrome; the pad inside draws no glass of its own.
            HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                          onSearchInstead: {
                              showPad = false
                              model.openLectern(.search)
                          }, onGo: { _ in
                              showPad = false
                              model.openPreview()
                          })
                .frame(width: 360)
                .environment(\.dsOnGlass, true)
                .dsSurface(settings.surface)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $model.showShare) {
            ShareSheet(items: [AppInfo.shareText, AppInfo.appStoreURL]).presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var panel: some View {
        switch model.lectern {
        case .collapsed: EmptyView()
        case .hymn: hymnTray
        case .pad: pad
        case .search: searchPanel
        case .library: libraryPanel
        case .more: morePanel
        case .hymnals: hymnalsPanel
        }
    }

    private var hymnFamily: Bool { [.hymn, .hymnals, .more].contains(model.lectern) }
    private var jumpFamily: Bool { [.pad, .search].contains(model.lectern) || showPad }

    private var statusLine: String {
        if player.isPlaying, player.hymn?.id == model.hymn.id {
            return player.currentVerse.map { "Playing · verse \($0) · piano" } ?? "Playing · intro · piano"
        }
        return model.hymn.hasAccompaniment ? "\(model.hymnalInfo.name) · piano ready" : model.hymnalInfo.name
    }

    private func jumpTapped() {
        if sizeClass == .regular {
            if jumpFamily { showPad = false; model.closeLectern() } else { showPad = true }
            return
        }
        jumpFamily ? model.closeLectern() : model.openLectern(.pad)
    }

    private func libraryTapped() {
        if sizeClass == .regular {
            model.revealSidebar = true
            return
        }
        model.lectern == .library ? model.closeLectern() : model.openLectern(.library)
    }

    /// Rejects numbers past the end of the hymnal. The pad writes through this binding.
    private var guardedDigits: Binding<String> {
        Binding(get: { model.digits }, set: { proposed in
            if proposed.count <= model.digits.count {
                model.digits = proposed
                return
            }
            guard let value = Int(proposed), value <= max(model.hymnal.info.maxNumber, 1) else {
                Haptics.rigid()
                return
            }
            model.digits = proposed
        })
    }

    private func title(for number: Int) -> String? { model.hymnal.hymn(number: number)?.title }

    private var recentSummaries: [DSHymnSummary] {
        model.recents.compactMap { number in
            model.hymnal.hymn(number: number).map { DSHymnSummary(number: number, title: $0.title) }
        }
    }

    // MARK: Hymn tray

    private var hymnTray: some View {
        HStack(spacing: DS.Space.s) {
            TrayTile(label: model.isFavourite ? "Saved" : "Save", isOn: model.isFavourite, onColor: settings.surface.brass) {
                Image(systemName: model.isFavourite ? "star.fill" : "star")
                    .contentTransition(.symbolEffect(.replace))
            } action: { model.toggleFavourite() }
            TrayTile(label: "Church", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "rectangle.on.rectangle")
            } action: { model.closeLectern(); model.showChurchMode = true }
            TrayTile(label: "Hymnal", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "globe")
            } action: { model.openLectern(.hymnals) }
            TrayTile(label: "Text", isOn: false, onColor: settings.surface.tint) {
                Text("Aa").font(DS.Typeface.panelTitle)
            } action: { model.closeLectern(); model.showAppearance = true }
            TrayTile(label: "More", isOn: false, onColor: settings.surface.tint) {
                Image(systemName: "ellipsis")
            } action: { model.openLectern(.more) }
        }
        .padding(.horizontal, DS.Space.panel)
        .padding(.top, DS.Space.panel)
        .padding(.bottom, DS.Space.xs)
    }

    // MARK: Number pad

    private var pad: some View {
        HymnNumberPad(digits: guardedDigits, title: title(for:), recents: recentSummaries, isStandalone: false,
                      onSearchInstead: { model.openLectern(.search) },
                      onGo: { _ in model.openPreview() })
    }

    // MARK: Word search

    private var searchPanel: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(settings.surface.secondary)
                    TextField("Words in a title or lyric", text: $model.query)
                        .focused($searchFocused)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            if let first = model.searchHits.first {
                                Analytics.track(.searchUsed(lyrics: model.searchLyrics))
                                model.show(first.hymn)
                            }
                        }
                        .accessibilityLabel("Search words in a title or lyric")
                }
                .padding(.horizontal, DS.Space.m)
                .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
                .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                Button("123") { model.openLectern(.pad) }
                    .font(DS.Typeface.button)
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: DS.Size.hitTarget)
                    .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Enter a number instead")
            }

            HStack {
                HStack(spacing: DS.Space.xs) {
                    ScopeChip(title: "Lyrics", isOn: model.searchLyrics) { model.searchLyrics = true }
                    ScopeChip(title: "Titles", isOn: !model.searchLyrics) { model.searchLyrics = false }
                }
                Spacer()
                Text(model.searchHits.isEmpty ? "" : "\(model.searchHits.count) hymn\(model.searchHits.count == 1 ? "" : "s")")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(settings.surface.secondary)
            }
            .padding(.horizontal, DS.Space.xxs)

            ScrollView {
                VStack(spacing: DS.Space.xs) {
                    ForEach(model.searchHits.prefix(40)) { hit in
                        HymnRow(hymn: hit.hymn.designSummary, snippet: hit.snippet, highlight: model.query,
                                isFavourite: model.favouriteNumbers.contains(hit.hymn.id),
                                isCurrent: hit.hymn.id == model.hymn.id, style: .inset) {
                            Analytics.track(.searchUsed(lyrics: model.searchLyrics))
                            model.show(hit.hymn)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(DS.Space.panel)
    }

    // MARK: Library

    private var libraryPanel: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                Picker("Library", selection: $model.libraryTab) {
                    ForEach(LibraryTab.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: DS.Size.hitTarget)
                GlassButton(title: "New playlist", systemImage: "plus", kind: .icon) { model.newPlaylist() }
            }

            switch model.libraryTab {
            case .favourites:
                ScrollView {
                    VStack(spacing: DS.Space.xs) {
                        ForEach(model.favouriteNumbers, id: \.self) { number in
                            if let hymn = model.hymnal.hymn(number: number) {
                                HymnRow(hymn: hymn.designSummary, isFavourite: true,
                                        isCurrent: hymn.id == model.hymn.id, style: .inset) { model.show(hymn) }
                            }
                        }
                        if model.favouriteNumbers.isEmpty {
                            Text("Star a hymn while you read to keep it here.")
                                .font(DS.Typeface.caption)
                                .foregroundStyle(settings.surface.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .scrollBounceBehavior(.basedOnSize)
            case .playlists:
                VStack(spacing: DS.Space.xs) {
                    ForEach(model.playlists) { list in
                        Button { model.play(list) } label: {
                            HStack(spacing: DS.Space.m) {
                                Image(systemName: "list.bullet")
                                    .foregroundStyle(settings.surface.tint)
                                    .frame(width: DS.Size.numberTile, height: DS.Size.numberTile)
                                    .background(RoundedRectangle.ds(DS.Radius.badge).fill(settings.surface.tint.opacity(DS.Fill.tintSelected)))
                                VStack(alignment: .leading, spacing: DS.Space.hair) {
                                    Text(list.name).font(DS.Typeface.rowTitle).lineLimit(1)
                                    Text(list.hymnNumbers.map(String.init).joined(separator: " · "))
                                        .font(DS.Typeface.caption)
                                        .foregroundStyle(settings.surface.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(settings.surface.secondary)
                            }
                            .padding(.horizontal, DS.Space.m)
                            .frame(maxWidth: .infinity, minHeight: DS.Size.row, alignment: .leading)
                            .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.row)))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Add hymn \(model.hymn.id)", systemImage: "plus") { model.addCurrentHymn(to: list) }
                            Button("Delete playlist", systemImage: "trash", role: .destructive) { model.delete(list) }
                        }
                        .accessibilityAction(named: "Add hymn \(model.hymn.id)") { model.addCurrentHymn(to: list) }
                        .accessibilityAction(named: "Delete playlist") { model.delete(list) }
                    }
                    if model.playlists.isEmpty {
                        Text("Build a set for Sabbath, choir practice or vespers. Touch and hold a playlist to add the open hymn.")
                            .font(DS.Typeface.caption)
                            .foregroundStyle(settings.surface.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(DS.Space.panel)
    }

    // MARK: More

    private var morePanel: some View {
        @Bindable var settings = settings
        return VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                Text("More").font(DS.Typeface.panelTitle)
                Spacer()
                Text("Advent Praise \(AppInfo.version)")
                    .dsEyebrow(tracking: 0.9)
                    .foregroundStyle(settings.surface.secondary)
            }
            ScrollView {
                VStack(spacing: DS.Space.m) {
                    DSInsetGroup(title: "Reading") {
                        MoreRow(title: "Appearance", detail: appearanceSummary) {
                            Text("Aa").font(DS.Typeface.label)
                        } action: {
                            model.closeLectern(); model.showAppearance = true
                        }
                        MoreToggleRow(title: "Large print", isOn: $settings.largePrint) {
                            Image(systemName: "textformat.size")
                        }
                        MoreToggleRow(title: "Chorus after every verse", isOn: $settings.repeatChorus) {
                            Image(systemName: "repeat")
                        }
                        MoreRow(title: "Church mode", detail: "One verse at a time") {
                            Image(systemName: "rectangle.on.rectangle")
                        } action: { model.closeLectern(); model.showChurchMode = true }
                        MoreRow(title: "Hymnals", detail: "\(model.hymnal.name) · \(HymnalInfo.catalogue.count)", isLast: true) {
                            Image(systemName: "globe")
                        } action: { model.openLectern(.hymnals) }
                    }
                    DSInsetGroup(title: "Help us improve") {
                        MoreRow(title: "Send a correction", detail: "Hymn \(model.hymn.id)") {
                            Image(systemName: "pencil.and.list.clipboard")
                        } action: { model.closeLectern(); model.mail = MailRequest(kind: .correction) }
                        MoreRow(title: "Request a hymnal or feature", isLast: true) {
                            Image(systemName: "envelope")
                        } action: { model.closeLectern(); model.mail = MailRequest(kind: .request) }
                    }
                    DSInsetGroup(title: "About") {
                        MoreRow(title: "Restore purchases") {
                            Image(systemName: "arrow.clockwise")
                        } action: { Task { await store.restore() } }
                        MoreRow(title: "Recommend Advent Praise") {
                            Image(systemName: "paperplane")
                        } action: { model.showShare = true }
                        MoreRow(title: "Rate on the App Store", isLast: true) {
                            Image(systemName: "star")
                        } action: { requestReview() }
                    }
                }
            }
            .frame(maxHeight: 440)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(DS.Space.panel)
    }

    private var appearanceSummary: String {
        let face = settings.style.font == .serif ? "Serif" : "Sans"
        return "\(settings.surface.rawValue.capitalized) · \(face) · \(Int(settings.style.basePointSize)) pt"
    }

    // MARK: Hymnals

    private var hymnalsPanel: some View {
        LanguagePicker(hymnals: HymnalInfo.catalogue.map(\.designHymnal),
                       access: access(for:),
                       unlockAllPrice: store.allHymnalsPrice,
                       isUnlockingAll: store.purchasing == PurchaseConfig.allHymnalsProductID,
                       ownsEverything: store.ownsEverything || PurchaseConfig.allHymnalsProductID == nil,
                       onSelect: select(_:),
                       onUnlockAll: { Task { await store.purchaseAll() } },
                       onRestore: { Task { await store.restore() } })
    }

    private func access(for hymnal: DSHymnal) -> DSHymnalAccess {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return .locked(price: nil) }
        if store.purchasing == info.id { return .purchasing }
        if info.id == model.hymnal.id { return .current }
        if store.isOwned(info) { return .owned }
        return .locked(price: store.price(for: info))
    }

    private func select(_ hymnal: DSHymnal) {
        guard let info = HymnalInfo.with(id: hymnal.id) else { return }
        if store.isOwned(info) {
            model.switchHymnal(to: info)
        } else {
            Task { if await store.purchase(info) { model.switchHymnal(to: info) } }
        }
    }
}

// MARK: - Pieces

private struct TrayTile<Icon: View>: View {
    let label: String
    let isOn: Bool
    let onColor: Color
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Space.xs) {
                icon.font(.system(size: 20))
                Text(label).font(DS.Typeface.eyebrow)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle.ds(DS.Radius.tile)
                .fill(isOn ? onColor.opacity(DS.Fill.tintOn) : Color.primary.opacity(DS.Fill.inset)))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(isOn ? onColor : .primary)
        .accessibilityLabel(label)
    }
}

private struct ScopeChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(title, action: action)
            .font(DS.Typeface.caption.weight(isOn ? .bold : .semibold))
            .padding(.horizontal, DS.Space.m)
            .frame(minHeight: 32)
            .background(Capsule().fill(isOn ? surface.tint.opacity(DS.Fill.tintSelected) : .clear))
            .overlay(Capsule().strokeBorder(isOn ? .clear : .primary.opacity(DS.Fill.stroke)))
            .foregroundStyle(isOn ? surface.tint : surface.secondary)
    }
}

private struct MoreRow<Icon: View>: View {
    let title: String
    var detail: String? = nil
    var isLast = false
    @ViewBuilder let icon: Icon
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                icon.font(.system(size: 18)).foregroundStyle(surface.tint).frame(width: 28)
                Text(title).font(DS.Typeface.label)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail).font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(surface.secondary)
            }
            .padding(.horizontal, DS.Space.m)
            .frame(minHeight: 46)
            .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, 52) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MoreToggleRow<Icon: View>: View {
    let title: String
    @Binding var isOn: Bool
    @ViewBuilder let icon: Icon
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DS.Space.m) {
                icon.font(.system(size: 18)).foregroundStyle(surface.tint).frame(width: 28)
                Text(title).font(DS.Typeface.label)
            }
        }
        .tint(surface.tint)
        .padding(.horizontal, DS.Space.m)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 52) }
    }
}

/// UIActivityViewController for "Recommend".
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
