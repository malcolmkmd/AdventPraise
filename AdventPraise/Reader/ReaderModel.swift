//
//  ReaderModel.swift
//  Advent Praise
//
//  The reader's state: which hymnal is open, which hymn, the Lectern, the
//  library (favourites, recents, playlists) and the sheets hanging off it.
//  Shared by the reader, the iPad sidebar and the App Intents.
//

import SwiftUI
import Observation

enum LecternState: Equatable { case collapsed, hymn, pad, search, library, hymnals }

enum LibraryTab: String, CaseIterable, Identifiable {
    case favourites, playlists
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

struct Playlist: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var hymnNumbers: [Int]
}

/// What a correction / request email is about.
struct MailRequest: Identifiable {
    enum Kind: String { case correction, request }
    let id = UUID()
    let kind: Kind
}

@Observable
@MainActor
final class ReaderModel {
    private(set) var hymnal: Hymnal
    private(set) var hymn: Hymn

    var isFocused = false
    /// iPad: the Lectern asks the split view to show the sidebar.
    var revealSidebar = false
    var showAppearance = false
    var showMore = false
    var showShare = false
    var showChurchMode = false
    var mail: MailRequest?
    var lectern: LecternState = .collapsed
    var digits = ""
    var query = ""
    var searchLyrics = true
    var libraryTab: LibraryTab = .favourites
    var favourites: Set<String> { didSet { defaults.set(Array(favourites), forKey: Keys.favourites) } }
    var playlists: [Playlist] { didSet { savePlaylists() } }
    private(set) var recents: [Int]
    private var activePlaylist: (id: UUID, index: Int)?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let hymnal = "reader.hymnal"
        static let lastHymn = "reader.lastHymn"
        static let favourites = "reader.favourites.v2"
        static let recents = "reader.recents"
        static let playlists = "reader.playlists.v1"
    }

    init() {
        let info = HymnalInfo.with(id: UserDefaults.standard.string(forKey: Keys.hymnal)) ?? .default
        let hymnal = Hymnal.load(info) ?? Hymnal.load(.default) ?? .empty(.default)
        self.hymnal = hymnal
        let last = UserDefaults.standard.integer(forKey: Keys.lastHymn)
        hymn = hymnal.hymn(number: last) ?? hymnal.hymns.first ?? Self.placeholder
        favourites = Set(UserDefaults.standard.stringArray(forKey: Keys.favourites) ?? [])
        recents = UserDefaults.standard.array(forKey: Keys.recents) as? [Int] ?? []
        playlists = (UserDefaults.standard.data(forKey: Keys.playlists))
            .flatMap { try? JSONDecoder().decode([Playlist].self, from: $0) } ?? []
    }

    private static let placeholder = Hymn(id: 0, title: "Advent Praise", references: [], blocks: [],
                                          midiResource: nil, verseStartBeats: [])

    var hymnalInfo: HymnalInfo { hymnal.info }
    /// Favourites are per hymnal: "english#12".
    private func favouriteKey(_ number: Int) -> String { "\(hymnal.id)#\(number)" }
    var isFavourite: Bool { favourites.contains(favouriteKey(hymn.id)) }
    var favouriteNumbers: [Int] {
        favourites.compactMap { key -> Int? in
            let parts = key.split(separator: "#")
            return parts.count == 2 && parts[0] == hymnal.id ? Int(parts[1]) : nil
        }.sorted()
    }
    var previewHymn: Hymn? { Int(digits).flatMap(hymnal.hymn(number:)) }
    var searchHits: [SearchHit] {
        query.trimmingCharacters(in: .whitespaces).count >= 2 || Int(query) != nil
            ? hymnal.search(query, inLyrics: searchLyrics) : []
    }
    var nextHymn: Hymn? { hymnal.hymn(after: hymn.id, offset: 1) }
    var previousHymn: Hymn? { hymnal.hymn(after: hymn.id, offset: -1) }

    // MARK: Intents

    func toggleFocus() {
        if lectern != .collapsed { closeLectern(); return }
        isFocused.toggle()
    }

    func openLectern(_ state: LecternState) {
        isFocused = false
        if state == .pad { digits = "" }
        lectern = state
        Haptics.soft()
    }

    func closeLectern() { lectern = .collapsed; Haptics.soft() }

    func push(_ digit: String) {
        guard digits.count < 4 else { return }
        let next = digits == "0" ? digit : digits + digit
        // Like the legacy pad: never accept a number past the end of the hymnal.
        guard let value = Int(next), value <= max(hymnal.info.maxNumber, 1) else { Haptics.rigid(); return }
        digits = next
        if previewHymn != nil { Haptics.rigid() } else { Haptics.light() }
    }

    func backspace() { digits = String(digits.dropLast()) }
    func clearDigits() { digits = "" }

    func openPreview() {
        guard let target = previewHymn else { return }
        show(target)
    }

    func show(_ target: Hymn) {
        hymn = target
        lectern = .collapsed
        defaults.set(target.id, forKey: Keys.lastHymn)
        recents.removeAll { $0 == target.id }
        recents.insert(target.id, at: 0)
        recents = Array(recents.prefix(3))
        defaults.set(recents, forKey: Keys.recents)
        Analytics.track(.hymnOpened(hymnal: hymnal.id, number: target.id))
    }

    /// Opens hymn `number` in the current hymnal; false if it doesn't exist.
    @discardableResult
    func open(number: Int) -> Bool {
        guard let target = hymnal.hymn(number: number) else { return false }
        activePlaylist = nil
        show(target)
        return true
    }

    /// Next hymn: the next playlist entry when a playlist is running, else the next number.
    @discardableResult
    func goToNextHymn() -> Hymn? {
        if let next = advancePlaylist() { return next }
        guard let next = nextHymn else { return nil }
        show(next)
        return next
    }

    @discardableResult
    func goToPreviousHymn() -> Hymn? {
        guard let previous = previousHymn else { return nil }
        activePlaylist = nil
        show(previous)
        return previous
    }

    /// Switch vernacular hymnal, keeping the same hymn number where it exists.
    /// Callers check ownership first.
    func switchHymnal(to info: HymnalInfo) {
        guard info.id != hymnal.id else { closeLectern(); return }
        guard let loaded = Hymnal.load(info) else { return }
        hymnal = loaded
        activePlaylist = nil
        defaults.set(info.id, forKey: Keys.hymnal)
        if let same = loaded.hymn(number: hymn.id) { show(same) }
        else if let first = loaded.hymns.first { show(first) }
        Analytics.track(.hymnalSwitched(hymnal: info.id))
        Haptics.rigid()
    }

    func toggleFavourite() {
        let key = favouriteKey(hymn.id)
        if favourites.contains(key) { favourites.remove(key) } else { favourites.insert(key) }
        Haptics.selection()
    }

    // MARK: Playlists

    func newPlaylist() {
        playlists.append(Playlist(id: UUID(), name: "Playlist \(playlists.count + 1)", hymnNumbers: [hymn.id]))
        libraryTab = .playlists
    }

    func addCurrentHymn(to playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[i].hymnNumbers.contains(hymn.id) else { return }
        playlists[i].hymnNumbers.append(hymn.id)
        Haptics.selection()
    }

    func delete(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
    }

    func play(_ playlist: Playlist) {
        guard let first = playlist.hymnNumbers.first, let target = hymnal.hymn(number: first) else { return }
        show(target)
        activePlaylist = (playlist.id, 0)
    }

    /// Advance within the active playlist (also the engine's onFinish).
    func advancePlaylist() -> Hymn? {
        guard let (id, index) = activePlaylist,
              let list = playlists.first(where: { $0.id == id }),
              index + 1 < list.hymnNumbers.count,
              let next = hymnal.hymn(number: list.hymnNumbers[index + 1]) else {
            activePlaylist = nil
            return nil
        }
        show(next)
        activePlaylist = (id, index + 1)
        return next
    }

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) { defaults.set(data, forKey: Keys.playlists) }
    }
}
