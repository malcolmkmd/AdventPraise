//
//  ChurchPresenterSheets.swift
//  Advent Praise
//
//  Church mode's presenter sheets: an announcement for the big screen (with
//  recent messages), and a picture from Photos (PhotosPicker: no library
//  permission) with recent pictures kept in the app's own storage. Both go
//  on ChurchPresentation, so the external display and the AirPlay video
//  show them; Clear goes back to blank or the words.
//

import PhotosUI
import SwiftUI
import UIKit

struct ChurchAnnouncementSheet: View {
    let church: ChurchPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var recents: [String] = AnnouncementRecents.load()
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Welcome! Please silence your phones.", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(.title3, design: .serif))
                        .focused($focused)
                } footer: {
                    Text("Shows large and centred on the TV, over the blank screen or a picture.")
                }
                if !recents.isEmpty {
                    Section("Recent") {
                        ForEach(recents, id: \.self) { message in
                            Button { text = message } label: {
                                Text(message).lineLimit(2).foregroundStyle(.primary)
                            }
                        }
                        .onDelete { offsets in
                            recents.remove(atOffsets: offsets)
                            AnnouncementRecents.save(recents)
                        }
                    }
                }
                if church.announcement != nil {
                    Section {
                        Button("Clear the announcement", role: .destructive) {
                            church.announcement = nil
                            Haptics.play(.toggleOff)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show") {
                        church.announcement = trimmed
                        recents = AnnouncementRecents.add(trimmed)
                        Haptics.play(.toggleOn)
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .onAppear {
                text = church.announcement ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum AnnouncementRecents {
    private static let key = "church.announcements.recent"
    static func load() -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
    static func save(_ list: [String]) { UserDefaults.standard.set(list, forKey: key) }
    @discardableResult
    static func add(_ message: String) -> [String] {
        var list = load().filter { $0 != message }
        list.insert(message, at: 0)
        list = Array(list.prefix(6))
        save(list)
        return list
    }
}

// MARK: - Image

struct ChurchImageSheet: View {
    let church: ChurchPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var recents: [ChurchImageStore.Entry] = ChurchImageStore.recents()
    @State private var isLoading = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    if isLoading { ProgressView().frame(maxWidth: .infinity) }
                    if failed { Text("Couldn't open that picture.").font(.footnote).foregroundStyle(.red) }
                    if !recents.isEmpty {
                        Text("Recent").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: DS.Space.s)],
                                  spacing: DS.Space.s) {
                            ForEach(recents) { entry in
                                Button { show(entry) } label: {
                                    Image(uiImage: entry.thumbnail)
                                        .resizable().scaledToFill()
                                        .frame(height: 90).frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay {
                                            if church.imageID == entry.id {
                                                RoundedRectangle(cornerRadius: 10).strokeBorder(.tint, lineWidth: 3)
                                            }
                                        }
                                }
                                .accessibilityLabel("Recent picture")
                            }
                        }
                    }
                    Text("The picture fills the TV on black. An announcement shows over it.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if church.image != nil {
                        Button("Clear the picture", role: .destructive) {
                            church.image = nil
                            church.imageID = nil
                            Haptics.play(.toggleOff)
                            dismiss()
                        }
                    }
                }
                .padding(DS.Space.l)
            }
            .navigationTitle("Show image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                isLoading = true
                failed = false
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    isLoading = false
                    guard let data, let entry = ChurchImageStore.add(data) else { failed = true; return }
                    recents = ChurchImageStore.recents()
                    show(entry)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func show(_ entry: ChurchImageStore.Entry) {
        guard let image = ChurchImageStore.image(entry.id) else { failed = true; return }
        church.image = image
        church.imageID = entry.id
        Haptics.play(.toggleOn)
        dismiss()
    }
}

/// Recent pictures: downscaled JPEGs in Application Support, newest first, six kept.
enum ChurchImageStore {
    struct Entry: Identifiable {
        let id: String
        let thumbnail: UIImage
    }

    private static let keep = 6
    private static var folder: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("church-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func files() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        func date(_ u: URL) -> Date {
            (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return urls.filter { $0.pathExtension == "jpg" }.sorted { date($0) > date($1) }
    }

    static func recents() -> [Entry] {
        files().compactMap { url in
            guard let image = UIImage(contentsOfFile: url.path),
                  let thumb = image.preparingThumbnail(of: CGSize(width: 240, height: 240)) else { return nil }
            return Entry(id: url.deletingPathExtension().lastPathComponent, thumbnail: thumb)
        }
    }

    static func image(_ id: String) -> UIImage? {
        let url = folder.appendingPathComponent("\(id).jpg")
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return UIImage(contentsOfFile: url.path)
    }

    /// Saves a picked picture (at most 1920 px on its long side).
    static func add(_ data: Data) -> Entry? {
        guard let source = UIImage(data: data) else { return nil }
        let longSide = max(source.size.width, source.size.height)
        let scale = min(1, 1920 / max(longSide, 1))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        let id = UUID().uuidString
        try? jpeg.write(to: folder.appendingPathComponent("\(id).jpg"))
        for old in files().dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
        return Entry(id: id, thumbnail: image.preparingThumbnail(of: CGSize(width: 240, height: 240)) ?? image)
    }
}
