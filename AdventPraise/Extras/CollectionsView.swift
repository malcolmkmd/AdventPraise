//
//  CollectionsView.swift
//  Advent Praise
//
//  The SDA Hymnal's sections, a page in More. Each pushes its
//  hymns in the current hymnal (`CollectionHymnsPage`), which can be opened
//  one at a time, run in church mode, or copied into a new service plan.
//

import SwiftUI

struct CollectionsPage: View {
    let model: ReaderModel
    let openCollection: (HymnCollection) -> Void

    private var collections: [HymnCollection] { HymnCollections.available(in: model.hymnal.id) }

    var body: some View {
        let collections = collections
        DrawerPageLayout {
            if collections.isEmpty {
                DrawerNote(HymnCollections.all.isEmpty
                           ? "Collections couldn’t be loaded."
                           : "Collections follow the sections of the SDA Hymnal. They’re available for Christ In Song in its languages, not for \(model.hymnal.name).")
            } else {
                DSInsetGroup {
                    ForEach(collections) { collection in
                        let count = collection.numbers(in: model.hymnal.id).count
                        MoreRow(title: "\(collection.title)",
                                detail: count == 1 ? String(localized: "1 hymn") : String(localized: "\(count) hymns"),
                                isLast: collection == collections.last) {
                            Image(systemName: collection.symbol)
                        } action: { openCollection(collection) }
                    }
                }
                DrawerNote("The sections of the Seventh-day Adventist Hymnal (1985). Hymns are placed by their SDA Hymnal number; hymns that aren’t in the SDA Hymnal aren’t in a section.")
            }
        }
        .analyticsScreen(.collections)
    }
}
