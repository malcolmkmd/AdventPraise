//
//  LecternView.swift
//  Advent Praise
//
//  The Lectern: one floating glass capsule that is the app's entire
//  navigation. Collapsed it holds play/stop, the current hymn, and two
//  buttons. It springs open into the number pad, word search, or the
//  Favourites / Playlists library, then settles back to 64 pt.
//

import SwiftUI

struct LecternView: View {
    @Bindable var model: ReaderModel
    @Environment(HymnMIDIEngine.self) private var player
    @Environment(ReadingSettings.self) private var settings
    @Environment(PurchaseStore.self) private var store
    @Environment(\.openURL) private var openURL
    @FocusState private var searchFocused: Bool

    private var env: ReadingEnvironment { settings.environment }
    private var radius: CGFloat { model.lectern == .collapsed ? Vesper.Radius.dock : 30 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    /// The row is the spine: it never moves. Panels unfold upward out of it,
    /// so a thumb that pressed a button in the row watches the result grow
    /// from under that same thumb.
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.lectern {
                case .collapsed: EmptyView()
                case .hymn: hymnTray.transition(panelTransition)
                case .pad: padPanel.transition(panelTransition)
                case .search: searchPanel.transition(panelTransition)
                case .library: libraryPanel.transition(panelTransition)
                case .more: morePanel.transition(panelTransition)
                case .hymnals: hymnalsPanel.transition(panelTransition)
                }
            }
            row
                .overlay(alignment: .top) {
                    if model.lectern != .collapsed { Divider().opacity(0.6) }
                }
        }
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .glassSurface(shape, depth: .capsule, isDark: env.isDark)
        .animation(.spring(duration: 0.45, bounce: 0.25), value: model.lectern)
        .animation(.spring(duration: 0.45, bounce: 0.25), value: model.libraryTab)
        .onChange(of: model.lectern) { _, state in searchFocused = (state == .search) }
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height < -40, model.lectern == .collapsed { model.openLectern(.hymn) }
                if value.translation.height > 40, model.lectern != .collapsed { model.closeLectern() }
            }
        )
    }

    private var panelTransition: AnyTransition {
        .opacity.combined(with: .move(edge: .bottom))
    }

    private var hymnFamily: Bool { [.hymn, .hymnals, .more].contains(model.lectern) }
    private var jumpFamily: Bool { [.pad, .search].contains(model.lectern) }

    // MARK: The row (always present)

    private var row: some View {
        HStack(spacing: 8) {
            // Accompaniment is paused for 7.0: the control only exists for hymns with a MIDI file.
            if model.hymn.hasAccompaniment {
                Button {
                    player.toggle(); Haptics.light()
                } label: {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(env.isDark ? Color.black : .white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(env.tint).shadow(color: env.tint.opacity(0.35), radius: 6, y: 3))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(player.isPlaying ? "Stop accompaniment" : "Play accompaniment")
            } else {
                Button { model.showChurchMode = true } label: {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(env.isDark ? Color.black : .white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(env.tint).shadow(color: env.tint.opacity(0.35), radius: 6, y: 3))
                }
                .accessibilityLabel("Church mode")
                .accessibilityHint("Shows one verse at a time in large, high-contrast text")
            }

            // The title is the handle for everything about this hymn.
            Button {
                hymnFamily ? model.closeLectern() : model.openLectern(.hymn)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(model.hymn.id))
                            .scaledFont(size: 18, weight: .semibold, design: .serif)
                            .foregroundStyle(env.brass)
                        Text(model.hymn.title)
                            .scaledFont(size: 14, weight: .semibold)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Text(statusLine).scaledFont(size: 12).foregroundStyle(.secondary).lineLimit(1)
                            .contentTransition(.numericText())
                        if player.isPlaying { PlaybackBars(isAnimating: true, color: env.tint, height: 12) }
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(env.tint.opacity(hymnFamily ? 0.10 : 0)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hymn \(model.hymn.id), \(model.hymn.title)")
            .accessibilityHint(hymnFamily ? "Closes hymn actions" : "Opens hymn actions: save, church mode, hymnal, text, more")
            .accessibilityAddTraits(hymnFamily ? .isSelected : [])

            LecternIconButton(systemImage: "circle.grid.3x3.fill", label: "Go to a hymn number or search",
                              isOn: jumpFamily, tint: env.tint) {
                jumpFamily ? model.closeLectern() : model.openLectern(.pad)
            }
            LecternIconButton(systemImage: "bookmark", label: "Favourites and playlists",
                              isOn: model.lectern == .library, tint: env.tint) {
                model.lectern == .library ? model.closeLectern() : model.openLectern(.library)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 64)
    }

    private var statusLine: String {
        if player.isPlaying, player.hymn?.id == model.hymn.id {
            return player.currentVerse.map { "Playing · verse \($0) · piano" } ?? "Playing · intro · piano"
        }
        return model.hymn.hasAccompaniment ? "\(model.hymnalInfo.name) · piano ready" : model.hymnalInfo.name
    }

    // MARK: Hymn tray — Save · Church · Hymnal · Text · More

    private var hymnTray: some View {
        HStack(spacing: 8) {
            TrayTile(label: model.isFavourite ? "Saved" : "Save", isOn: model.isFavourite, onColor: env.brass) {
                Image(systemName: model.isFavourite ? "star.fill" : "star")
                    .contentTransition(.symbolEffect(.replace))
            } action: { model.toggleFavourite() }
            TrayTile(label: "Church", isOn: false, onColor: env.tint) {
                Image(systemName: "rectangle.on.rectangle")
            } action: { model.closeLectern(); model.showChurchMode = true }
            TrayTile(label: "Hymnal", isOn: false, onColor: env.tint) {
                Image(systemName: "globe")
            } action: { model.openLectern(.hymnals) }
            TrayTile(label: "Text", isOn: false, onColor: env.tint) {
                Text("Aa").scaledFont(size: 20, weight: .semibold, design: .serif)
            } action: { model.closeLectern(); model.showAppearance = true }
            TrayTile(label: "More", isOn: false, onColor: env.tint) {
                Image(systemName: "ellipsis")
            } action: { model.openLectern(.more) }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    // MARK: Number pad

    private var padPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack {
                    if model.digits.isEmpty {
                        Text("Hymn number").scaledFont(size: 15).foregroundStyle(.secondary)
                    } else {
                        Text(model.digits)
                            .scaledFont(size: 26, weight: .medium, design: .serif).monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.06)))
                .accessibilityLabel("Hymn number")
                .accessibilityValue(model.digits.isEmpty ? "empty" : model.digits)
                Button("Abc") { model.openLectern(.search) }
                    .scaledFont(size: 13, weight: .bold)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.06)))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Search by words instead")
            }

            VStack(alignment: .leading, spacing: 2) {
                if let preview = model.previewHymn {
                    Text(preview.title).scaledFont(size: 18, weight: .semibold, design: .serif).lineLimit(1)
                    Text("Hymn \(preview.id)\(preview.hasAccompaniment ? " · piano accompaniment" : "")")
                        .scaledFont(size: 12, weight: .semibold).tracking(0.7).textCase(.uppercase)
                        .foregroundStyle(env.brass)
                } else if model.digits.isEmpty {
                    Text("The title appears as you type.").scaledFont(size: 13).foregroundStyle(.secondary)
                } else {
                    Text("No hymn with that number").scaledFont(size: 17, design: .serif, italic: true).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 4)
            .animation(.easeInOut(duration: 0.2), value: model.previewHymn?.id)

            if !model.recents.isEmpty {
                HStack(spacing: 6) {
                    Text("Recent").scaledFont(size: 11, weight: .bold).tracking(1.3).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    ForEach(model.recents, id: \.self) { n in
                        if let h = model.hymnal.hymn(number: n) {
                            Button { model.digits = String(n); Haptics.rigid() } label: {
                                HStack(spacing: 4) {
                                    Text(String(n)).foregroundStyle(env.brass)
                                    Text(h.title).lineLimit(1)
                                }
                                .scaledFont(size: 12, weight: .semibold)
                                .padding(.horizontal, 10).frame(height: 32)
                                .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: 110)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...9, id: \.self) { n in
                    PadKey(label: String(n)) { model.push(String(n)) }
                }
                Button { model.backspace(); Haptics.light() } label: {
                    Image(systemName: "delete.left").scaledFont(size: 22)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonRepeatBehavior(.enabled)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Delete last digit")
                PadKey(label: "0") { model.push("0") }
                Button { model.openPreview() } label: {
                    Label("Go", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(env.tint)
                            .shadow(color: env.tint.opacity(0.3), radius: 8, y: 4))
                }
                .disabled(model.previewHymn == nil)
                .opacity(model.previewHymn == nil ? 0.5 : 1)
                .accessibilityLabel(model.previewHymn.map { "Go to hymn \($0.id), \($0.title)" } ?? "Go")
            }
        }
        .padding(14)
    }

    // MARK: Word search

    private var searchPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
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
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.06)))
                Button("123") { model.openLectern(.pad) }
                    .scaledFont(size: 13, weight: .bold)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.06)))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Enter a number instead")
            }

            HStack {
                HStack(spacing: 6) {
                    ScopeChip(title: "Lyrics", isOn: model.searchLyrics, tint: env.tint) { model.searchLyrics = true }
                    ScopeChip(title: "Titles", isOn: !model.searchLyrics, tint: env.tint) { model.searchLyrics = false }
                }
                Spacer()
                Text(model.searchHits.isEmpty ? "" : "\(model.searchHits.count) hymn\(model.searchHits.count == 1 ? "" : "s")")
                    .scaledFont(size: 12).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ScrollView {
              VStack(spacing: 6) {
                ForEach(model.searchHits.prefix(40)) { hit in
                    Button {
                        Analytics.track(.searchUsed(lyrics: model.searchLyrics))
                        model.show(hit.hymn)
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(hit.hymn.id))
                                .scaledFont(size: 17, weight: .semibold, design: .serif)
                                .foregroundStyle(env.tint)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(env.tint.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.hymn.title).scaledFont(size: 16, weight: .semibold, design: .serif).lineLimit(1)
                                Text(highlighted(hit.snippet, query: model.query))
                                    .scaledFont(size: 12).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hymn \(hit.hymn.id), \(hit.hymn.title)")
                    .accessibilityHint(hit.snippet)
                }
              }
            }
            .frame(maxHeight: 260)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(14)
    }

    private func highlighted(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        if let range = result.range(of: query, options: .caseInsensitive) {
            result[range].backgroundColor = env.brass.opacity(0.18)
            result[range].foregroundColor = env.foreground
        }
        return result
    }

    // MARK: Library

    private var libraryPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker("Library", selection: $model.libraryTab) {
                    ForEach(LibraryTab.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(height: 44)
                LecternIconButton(systemImage: "plus", label: "New playlist with this hymn") {
                    model.newPlaylist()
                }
            }

            switch model.libraryTab {
            case .favourites:
                ScrollView {
                  VStack(spacing: 6) {
                    ForEach(model.favouriteNumbers, id: \.self) { n in
                        if let h = model.hymnal.hymn(number: n) {
                            LibraryRow(leading: AnyView(Image(systemName: "star.fill").foregroundStyle(env.brass)),
                                       number: n, title: h.title, detail: nil, brass: env.brass) { model.show(h) }
                        }
                    }
                    Text(model.favouriteNumbers.isEmpty ? "Star a hymn while you read to keep it here." : "")
                        .scaledFont(size: 12).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                  }
                }
                .frame(maxHeight: 300)
                .scrollBounceBehavior(.basedOnSize)
            case .playlists:
                VStack(spacing: 6) {
                    ForEach(model.playlists) { list in
                        LibraryRow(leading: AnyView(
                            Image(systemName: "list.bullet").foregroundStyle(env.tint)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(env.tint.opacity(0.12)))),
                            number: nil, title: list.name,
                            detail: list.hymnNumbers.map(String.init).joined(separator: " · "),
                            brass: env.brass) { model.play(list) }
                        .contextMenu {
                            Button("Add hymn \(model.hymn.id)", systemImage: "plus") { model.addCurrentHymn(to: list) }
                            Button("Delete playlist", systemImage: "trash", role: .destructive) { model.delete(list) }
                        }
                        .accessibilityAction(named: "Add hymn \(model.hymn.id)") { model.addCurrentHymn(to: list) }
                        .accessibilityAction(named: "Delete playlist") { model.delete(list) }
                    }
                    if model.playlists.isEmpty {
                        Text("Build a set for Sabbath, choir practice or vespers. Touch and hold a playlist to add the open hymn.")
                            .scaledFont(size: 12).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding(14)
    }

    // MARK: More — settings and about

    private var morePanel: some View {
        @Bindable var settings = settings
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("More").scaledFont(size: 20, weight: .semibold, design: .serif)
                Spacer()
                Text("Advent Praise \(AppInfo.version)")
                    .scaledFont(size: 11, weight: .semibold).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
              VStack(spacing: 12) {
                MoreGroup(title: "Reading") {
                    MoreRow(title: "Appearance", detail: appearanceSummary, tint: env.tint) {
                        Text("Aa").scaledFont(size: 16, weight: .semibold, design: .serif)
                    } action: {
                        model.closeLectern(); model.showAppearance = true
                    }
                    MoreToggleRow(title: "Large print", tint: env.tint, isOn: Binding(
                        get: { settings.largePrint },
                        set: { settings.largePrint = $0; Analytics.track(.largePrintChanged(on: $0)) })) {
                        Image(systemName: "textformat.size")
                    }
                    MoreRow(title: "Church mode", detail: "One verse at a time", tint: env.tint) {
                        Image(systemName: "rectangle.on.rectangle")
                    } action: { model.closeLectern(); model.showChurchMode = true }
                    MoreRow(title: "Hymnals", detail: "\(model.hymnal.name) · \(HymnalInfo.catalogue.count)",
                            tint: env.tint, isLast: true) {
                        Image(systemName: "globe")
                    } action: { model.openLectern(.hymnals) }
                }

                MoreGroup(title: "Help us improve") {
                    MoreRow(title: "Send a correction", detail: "Hymn \(model.hymn.id)", tint: env.tint) {
                        Image(systemName: "pencil.and.list.clipboard")
                    } action: { model.closeLectern(); model.mail = MailRequest(kind: .correction) }
                    MoreRow(title: "Request a hymnal or feature", tint: env.tint, isLast: true) {
                        Image(systemName: "envelope")
                    } action: { model.closeLectern(); model.mail = MailRequest(kind: .request) }
                }

                MoreGroup(title: "About") {
                    MoreRow(title: "Restore purchases", tint: env.tint) {
                        Image(systemName: "arrow.clockwise")
                    } action: { Task { await store.restore() } }
                    MoreRow(title: "Recommend Advent Praise", tint: env.tint) { Image(systemName: "paperplane") } action: {
                        model.showShare = true
                    }
                    MoreRow(title: "Rate on the App Store", tint: env.brass) { Image(systemName: "star") } action: {
                        openURL(AppInfo.writeReviewURL)
                    }
                    MoreRow(title: "Privacy policy", tint: env.tint, isLast: true) { Image(systemName: "hand.raised") } action: {
                        openURL(AppInfo.privacyPolicyURL)
                    }
                }
              }
            }
            .frame(maxHeight: 440)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(14)
        .sheet(isPresented: $model.showShare) {
            ShareSheet(items: [AppInfo.shareText, AppInfo.appStoreURL]).presentationDetents([.medium, .large])
        }
    }

    private var appearanceSummary: String {
        "\(env.name) · \(settings.font.name) · \(Int(settings.pointSize)) pt"
    }

    // MARK: Hymnals — the globe

    private var hymnalsPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Hymnals").scaledFont(size: 20, weight: .semibold, design: .serif)
                Spacer()
                Text("\(HymnalInfo.catalogue.count) hymnals")
                    .scaledFont(size: 11, weight: .semibold).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(HymnalInfo.catalogue) { hymnal in
                        HymnalRow(hymnal: hymnal,
                                  isCurrent: model.hymnal.id == hymnal.id,
                                  isOwned: store.isOwned(hymnal),
                                  price: store.price(for: hymnal),
                                  isBusy: store.purchasing == hymnal.id,
                                  tint: env.tint, brass: env.brass) {
                            if store.isOwned(hymnal) {
                                model.switchHymnal(to: hymnal)
                            } else {
                                Task { if await store.purchase(hymnal) { model.switchHymnal(to: hymnal) } }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
            .scrollBounceBehavior(.basedOnSize)
            if let allID = PurchaseConfig.allHymnalsProductID, !store.ownsEverything {
                Button {
                    Task { await store.purchaseAll() }
                } label: {
                    HStack(spacing: 8) {
                        if store.purchasing == allID {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Text("Unlock all hymnals")
                            if let price = store.allHymnalsPrice {
                                Text(price).scaledFont(size: 12, weight: .bold)
                                    .padding(.horizontal, 8).frame(height: 24)
                                    .background(Capsule().fill(.white.opacity(0.18)))
                            }
                        }
                    }
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(env.tint)
                        .shadow(color: env.tint.opacity(0.3), radius: 8, y: 4))
                }
                .disabled(store.purchasing != nil || store.allHymnalsPrice == nil)
                .accessibilityLabel("Unlock all hymnals")
            }
            Button {
                Task { await store.restore() }
            } label: {
                if store.isRestoring { ProgressView().controlSize(.small) } else { Text("Restore purchases") }
            }
            .scaledFont(size: 13, weight: .bold)
            .foregroundStyle(env.tint)
            .frame(minHeight: 32)
            .disabled(store.isRestoring)
        }
        .padding(14)
    }
}

private struct HymnalRow: View {
    let hymnal: HymnalInfo
    let isCurrent: Bool
    let isOwned: Bool
    let price: String?
    let isBusy: Bool
    let tint: Color
    let brass: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hymnal.color).frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(hymnal.name).scaledFont(size: 15, weight: .semibold).lineLimit(1)
                    Text(hymnal.language).scaledFont(size: 12).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isBusy {
                    ProgressView().controlSize(.small)
                } else if isCurrent {
                    Image(systemName: "checkmark").scaledFont(size: 15, weight: .bold).foregroundStyle(tint)
                } else if isOwned {
                    Text("Owned").scaledFont(size: 11, weight: .bold).tracking(0.6).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                } else {
                    Label(price ?? "—", systemImage: "lock.fill")
                        .scaledFont(size: 12, weight: .bold)
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(Capsule().fill(brass.opacity(0.12)))
                        .foregroundStyle(brass)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrent ? tint.opacity(0.10) : .primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCurrent ? tint.opacity(0.35) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("\(hymnal.name), \(hymnal.language), \(isCurrent ? "current" : isOwned ? "owned" : "locked, \(price ?? "")")")
    }
}

// MARK: - More pieces

private struct MoreGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).scaledFont(size: 11, weight: .bold).tracking(1.3).textCase(.uppercase)
                .foregroundStyle(.secondary).padding(.horizontal, 4)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.05)))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct MoreRow<Icon: View>: View {
    let title: String
    var detail: String? = nil
    let tint: Color
    var isLast = false
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon.scaledFont(size: 18).foregroundStyle(tint).frame(width: 28)
                Text(title).scaledFont(size: 15, weight: .semibold)
                Spacer(minLength: 0)
                if let detail { Text(detail).scaledFont(size: 12).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").scaledFont(size: 13, weight: .semibold).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, 52) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MoreToggleRow<Icon: View>: View {
    let title: String
    let tint: Color
    @Binding var isOn: Bool
    @ViewBuilder let icon: Icon

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                icon.scaledFont(size: 18).foregroundStyle(tint).frame(width: 28)
                Text(title).scaledFont(size: 15, weight: .semibold)
            }
        }
        .tint(tint)
        .padding(.horizontal, 12)
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

// MARK: - Pieces

private struct LecternIconButton: View {
    let systemImage: String
    let label: String
    var isOn = false
    var tint: Color = .accentColor
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).scaledFont(size: 18, weight: .semibold)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? tint.opacity(0.14) : .primary.opacity(0.06)))
        }
        .foregroundStyle(isOn ? tint : .primary)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

private struct TrayTile<Icon: View>: View {
    let label: String
    let isOn: Bool
    let onColor: Color
    @ViewBuilder let icon: Icon
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon.scaledFont(size: 20)
                Text(label).scaledFont(size: 11, weight: .bold)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isOn ? onColor.opacity(0.14) : .primary.opacity(0.06)))
        }
        .buttonStyle(PressScaleStyle())
        .foregroundStyle(isOn ? onColor : .primary)
        .accessibilityLabel(label)
    }
}

private struct PadKey: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .scaledFont(size: 24, weight: .medium, design: .serif)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.background.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        }
        .buttonStyle(PressScaleStyle())
        .foregroundStyle(.primary)
        .accessibilityLabel("Digit \(label)")
    }
}

private struct ScopeChip: View {
    let title: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .scaledFont(size: 12, weight: isOn ? .bold : .semibold)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(isOn ? tint.opacity(0.12) : .clear))
            .overlay(Capsule().strokeBorder(isOn ? .clear : .primary.opacity(0.12)))
            .foregroundStyle(isOn ? tint : .secondary)
    }
}

private struct LibraryRow: View {
    let leading: AnyView
    let number: Int?
    let title: String
    let detail: String?
    let brass: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                if let number {
                    Text(String(number)).scaledFont(size: 16, weight: .semibold, design: .serif)
                        .foregroundStyle(brass).monospacedDigit().frame(width: 26, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).scaledFont(size: 16, weight: number == nil ? .semibold : .regular, design: .serif).lineLimit(1)
                    if let detail { Text(detail).scaledFont(size: 12).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").scaledFont(size: 13, weight: .semibold).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.35), value: configuration.isPressed)
    }
}
