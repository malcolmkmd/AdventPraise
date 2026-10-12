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

/// The playlist editor sheet, by playlist id.
struct PlaylistEditing: Identifiable, Hashable {
    let id: UUID
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
    /// iPad: the Lectern's library button asks the split view to show or hide the sidebar.
    var toggleSidebar = false
    var showAppearance = false
    var showMore = false
    var showShare = false
    var showChurchMode = false
    /// The Pro paywall, leading with the feature that asked for it.
    var paywall: ProFeature?
    var mail: MailRequest?
    var lectern: LecternState = .collapsed
    var digits = ""
    var query = ""
    var searchLyrics = true
    var libraryTab: LibraryTab = .favourites
    var favourites: Set<String> { didSet { defaults.set(Array(favourites), forKey: Keys.favourites) } }
    /// Playlists per hymnal id: hymn numbers mean different hymns in each hymnal.
    private var playlistsByHymnal: [String: [Playlist]] { didSet { savePlaylists() } }
    var editingPlaylist: PlaylistEditing?
    var isNamingNewPlaylist = false
    var playlistBeingRenamed: Playlist?
    /// Asks before deleting from a menu, swipe or VoiceOver action.
    var playlistPendingDeletion: Playlist?
    private(set) var recents: [Int]
    private var activePlaylist: (id: UUID, index: Int)?
    /// An unsaved ordered list (a service plan or collection) run like a playlist.
    private var activeQueue: (numbers: [Int], index: Int)?
    private let defaults = UserDefaults.standard
    /// Playlist Play: AppServices starts the accompaniment for the first hymn.
    @ObservationIgnored var onPlaylistStarted: ((Hymn) -> Void)?

    private enum Keys {
        static let hymnal = "reader.hymnal"
        static let lastHymn = "reader.lastHymn"
        static let favourites = "reader.favourites.v2"
        static let recents = "reader.recents"
        /// v1: one [Playlist] shared by every hymnal. Read once to migrate, never written.
        static let legacyPlaylists = "reader.playlists.v1"
        /// v2: [hymnal id: [Playlist]].
        static let playlists = "reader.playlists.v2"
    }

    init() {
        let info = HymnalInfo.with(id: UserDefaults.standard.string(forKey: Keys.hymnal)) ?? .default
        let hymnal = Hymnal.load(info) ?? Hymnal.load(.default) ?? .empty(.default)
        self.hymnal = hymnal
        let last = UserDefaults.standard.integer(forKey: Keys.lastHymn)
        hymn = hymnal.hymn(number: last) ?? hymnal.hymns.first ?? Self.placeholder
        favourites = Set(UserDefaults.standard.stringArray(forKey: Keys.favourites) ?? [])
        recents = UserDefaults.standard.array(forKey: Keys.recents) as? [Int] ?? []
        let (loaded, migrated) = Self.loadPlaylists(currentHymnal: hymnal.id)
        playlistsByHymnal = loaded
        if migrated { savePlaylists() }
    }

    /// Reads v2. Without a readable v2, moves the v1 lists (names, ids and
    /// order kept) into the hymnal that is open; v1 stays in UserDefaults
    /// untouched. `migrated` says v2 should be written now.
    private static func loadPlaylists(currentHymnal: String) -> (playlists: [String: [Playlist]], migrated: Bool) {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.playlists),
           let stored = try? JSONDecoder().decode([String: [Playlist]].self, from: data) {
            return (stored, false)
        }
        guard let data = defaults.data(forKey: Keys.legacyPlaylists),
              let legacy = try? JSONDecoder().decode([Playlist].self, from: data), !legacy.isEmpty else { return ([:], false) }
        return ([currentHymnal: legacy], true)
    }

    private static let placeholder = Hymn(id: 0, title: "Advent Praise", references: [], blocks: [],
                                          midiResource: nil)

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
    var nextHymn: Hymn? {
        if let (numbers, index) = activeQueue {
            return numbers.dropFirst(index + 1).lazy.compactMap(hymnal.hymn(number:)).first
        }
        return hymnal.hymn(after: hymn.id, offset: 1)
    }
    var previousHymn: Hymn? { hymnal.hymn(after: hymn.id, offset: -1) }
    /// Where "next" goes: the next playlist entry while a playlist runs, else the next number.
    var upcomingHymn: Hymn? { playlistEntry(step: 1)?.hymn ?? nextHymn }
    /// Where "previous" goes: back through the running playlist, else the previous number.
    var precedingHymn: Hymn? { playlistEntry(step: -1)?.hymn ?? previousHymn }

    // MARK: Intents

    func toggleFocus() {
        if lectern != .collapsed { closeLectern(); return }
        isFocused.toggle()
    }

    func openLectern(_ state: LecternState) {
        isFocused = false
        if state == .pad { digits = "" }
        lectern = state
        Haptics.play(.softImpact)
    }

    /// Idempotent: a second call (e.g. one swipe seen by two gestures) does nothing.
    func closeLectern() {
        guard lectern != .collapsed else { return }
        lectern = .collapsed
        Haptics.play(.softImpact)
    }

    func push(_ digit: String) {
        guard digits.count < 4 else { Haptics.play(.limit); return }
        let next = digits == "0" ? digit : digits + digit
        // Like the legacy pad: never accept a number past the end of the hymnal.
        guard let value = Int(next), value <= max(hymnal.info.maxNumber, 1) else { Haptics.play(.limit); return }
        digits = next
        Haptics.play(.keyPress)
    }

    func backspace() { digits = String(digits.dropLast()) }
    func clearDigits() { digits = "" }

    func openPreview() {
        guard let target = previewHymn else { return }
        show(target)
    }

    /// `feedback` is felt when the hymn actually changes. Callers pass nil
    /// for changes the user didn't make by touch (playlist auto-advance,
    /// Siri, the lock screen).
    func show(_ target: Hymn, feedback: HapticEvent? = .pageTurn) {
        if target != hymn, let feedback { Haptics.play(feedback) }
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
    func open(number: Int, feedback: HapticEvent? = .pageTurn) -> Bool {
        guard let target = hymnal.hymn(number: number) else { return false }
        activePlaylist = nil
        activeQueue = nil
        show(target, feedback: feedback)
        return true
    }

    /// Next hymn: the next playlist entry when a playlist is running, else the next number.
    @discardableResult
    func goToNextHymn(feedback: HapticEvent? = .pageTurn) -> Hymn? {
        let wasQueued = activeQueue != nil
        if let next = advancePlaylist(feedback: feedback) { return next }
        guard !wasQueued, let next = nextHymn else { return nil }   // a finished queue ends there
        show(next, feedback: feedback)
        return next
    }

    @discardableResult
    func goToPreviousHymn(feedback: HapticEvent? = .pageTurn) -> Hymn? {
        if let (previous, index) = playlistEntry(step: -1), let id = activePlaylist?.id {
            show(previous, feedback: feedback)
            activePlaylist = (id, index)
            return previous
        }
        guard let previous = previousHymn else { return nil }
        activePlaylist = nil
        activeQueue = nil
        show(previous, feedback: feedback)
        return previous
    }

    /// Switch vernacular hymnal, keeping the same hymn number where it exists.
    /// Callers check ownership first. One firmer tap for the switch, not a
    /// page turn on top of it.
    func switchHymnal(to info: HymnalInfo, feedback: HapticEvent? = .mediumImpact) {
        guard info.id != hymnal.id else { closeLectern(); return }
        guard let loaded = Hymnal.load(info) else { return }
        hymnal = loaded
        activePlaylist = nil
        activeQueue = nil
        defaults.set(info.id, forKey: Keys.hymnal)
        if let same = loaded.hymn(number: hymn.id) { show(same, feedback: nil) }
        else if let first = loaded.hymns.first { show(first, feedback: nil) }
        Analytics.track(.hymnalSwitched(hymnal: info.id))
        if let feedback { Haptics.play(feedback) }
    }

    func toggleFavourite() {
        let key = favouriteKey(hymn.id)
        if favourites.contains(key) { favourites.remove(key) } else { favourites.insert(key) }
        Haptics.play(.toggle(favourites.contains(key)))
    }

    // MARK: Playlists

    /// The open hymnal's playlists.
    var playlists: [Playlist] {
        get { playlistsByHymnal[hymnal.id] ?? [] }
        set { playlistsByHymnal[hymnal.id] = newValue.isEmpty ? nil : newValue }
    }

    func playlist(id: UUID) -> Playlist? { playlists.first { $0.id == id } }

    /// "Playlist N", skipping names already in use.
    var nextPlaylistName: String {
        let names = Set(playlists.map(\.name))
        var n = playlists.count + 1
        while names.contains("Playlist \(n)") { n += 1 }
        return "Playlist \(n)"
    }

    /// Asks for a name; `createPlaylist(named:)` finishes the job.
    func newPlaylist() {
        libraryTab = .playlists
        isNamingNewPlaylist = true
    }

    /// Creates a playlist holding the open hymn and opens it in the editor.
    func createPlaylist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = Playlist(id: UUID(), name: trimmed.isEmpty ? nextPlaylistName : trimmed, hymnNumbers: [hymn.id])
        playlists.append(list)
        libraryTab = .playlists
        closeLectern()
        editingPlaylist = PlaylistEditing(id: list.id)
    }

    func edit(_ playlist: Playlist) {
        lectern = .collapsed
        editingPlaylist = PlaylistEditing(id: playlist.id)
    }

    /// An empty name keeps the old one.
    func rename(_ playlist: Playlist, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i].name = trimmed
    }

    /// Adds a hymn at the end; a playlist holds each hymn once.
    func add(_ number: Int, to playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[i].hymnNumbers.contains(number) else { return }
        playlists[i].hymnNumbers.append(number)
        Haptics.play(.toggleOn)
    }

    func addCurrentHymn(to playlist: Playlist) { add(hymn.id, to: playlist) }

    func remove(_ number: Int, from playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
              playlists[i].hymnNumbers.contains(number) else { return }
        playlists[i].hymnNumbers.removeAll { $0 == number }
        Haptics.play(.toggleOff)
    }

    func removeHymns(at offsets: IndexSet, from playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i].hymnNumbers.remove(atOffsets: offsets)
        Haptics.play(.toggleOff)
    }

    /// The drop of a drag reorder.
    func moveHymns(from source: IndexSet, to destination: Int, in playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i].hymnNumbers.move(fromOffsets: source, toOffset: destination)
        Haptics.play(.selection)
    }

    /// Moves one hymn up (-1) or down (+1): the VoiceOver alternative to dragging.
    func moveHymn(_ number: Int, by offset: Int, in playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
              let from = playlists[i].hymnNumbers.firstIndex(of: number),
              playlists[i].hymnNumbers.indices.contains(from + offset) else { return }
        playlists[i].hymnNumbers.swapAt(from, from + offset)
        Haptics.play(.selection)
    }

    /// Always after a confirmation alert, so one firm tap marks it done.
    func delete(_ playlist: Playlist) {
        if activePlaylist?.id == playlist.id { activePlaylist = nil }
        if editingPlaylist?.id == playlist.id { editingPlaylist = nil }
        playlists.removeAll { $0.id == playlist.id }
        Haptics.play(.mediumImpact)
    }

    /// Opens the playlist's hymn at `index`, follows the playlist from there
    /// and starts the accompaniment where there is one.
    func play(_ playlist: Playlist, from index: Int = 0) {
        guard playlist.hymnNumbers.indices.contains(index),
              let target = hymnal.hymn(number: playlist.hymnNumbers[index]) else { return }
        show(target)
        activePlaylist = (playlist.id, index)
        activeQueue = nil
        onPlaylistStarted?(target)
    }

    /// Runs `numbers` in order like a playlist without saving it. Numbers
    /// missing from the open hymnal are skipped. False if none exist.
    @discardableResult
    func play(queue numbers: [Int]) -> Bool {
        guard let start = numbers.firstIndex(where: { hymnal.hymn(number: $0) != nil }),
              let target = hymnal.hymn(number: numbers[start]) else { return false }
        show(target)
        activePlaylist = nil
        activeQueue = (numbers, start)
        return true
    }

    var activePlaylistID: UUID? { activePlaylist?.id }

    /// Where the open hymn sits in the running playlist. Follows the hymn
    /// rather than the stored index, so editing a running playlist doesn't
    /// derail it; if the open hymn was removed, carries on from where it was.
    private var activePosition: (list: Playlist, index: Int)? {
        guard let (id, stored) = activePlaylist, let list = playlist(id: id) else { return nil }
        if let index = list.hymnNumbers.firstIndex(of: hymn.id) { return (list, index) }
        return (list, min(stored, list.hymnNumbers.count) - 1)
    }

    /// "Sabbath · 2 of 5" while a playlist is running.
    var playlistProgress: String? {
        guard let (list, index) = activePosition, list.hymnNumbers.indices.contains(index),
              list.hymnNumbers[index] == hymn.id else { return nil }
        return "\(list.name) · \(index + 1) of \(list.hymnNumbers.count)"
    }

    /// The entry `step` places from the open hymn (+1 next, -1 previous)
    /// that this hymnal has, skipping numbers it lacks.
    private func playlistEntry(step: Int) -> (hymn: Hymn, index: Int)? {
        guard let (list, index) = activePosition else { return nil }
        // When the open hymn was removed, `index` is the entry before the gap.
        let onHymn = list.hymnNumbers.indices.contains(index) && list.hymnNumbers[index] == hymn.id
        var i = step < 0 && !onHymn ? index : index + step
        while list.hymnNumbers.indices.contains(i) {
            if let target = hymnal.hymn(number: list.hymnNumbers[i]) { return (target, i) }
            i += step
        }
        return nil
    }

    /// Advance within the active playlist (also the engine's onFinish, which
    /// stays quiet: nobody touched anything).
    func advancePlaylist(feedback: HapticEvent? = nil) -> Hymn? {
        if let (numbers, index) = activeQueue {
            guard let offset = numbers.dropFirst(index + 1).firstIndex(where: { hymnal.hymn(number: $0) != nil }),
                  let next = hymnal.hymn(number: numbers[offset]) else {
                activeQueue = nil
                return nil
            }
            show(next, feedback: feedback)
            activeQueue = (numbers, offset)
            return next
        }
        guard let id = activePlaylist?.id, let (next, index) = playlistEntry(step: 1) else {
            activePlaylist = nil
            return nil
        }
        show(next, feedback: feedback)
        activePlaylist = (id, index)
        return next
    }

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlistsByHymnal) { defaults.set(data, forKey: Keys.playlists) }
    }
}
