//
//  ReaderCommands.swift
//  Advent Praise
//
//  Hardware-keyboard shortcuts for the reader, listed in the iPadOS menu
//  bar and the ⌘-hold overlay. They act on the shared ReaderModel, the same
//  one the Lectern and the App Intents drive.
//

import SwiftUI

struct ReaderCommands: Commands {
    let model: ReaderModel

    var body: some Commands {
        CommandMenu("Hymn") {
            Button("Next Hymn") { model.goToNextHymn(source: .keyboard) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Previous Hymn") { model.goToPreviousHymn(source: .keyboard) }
                .keyboardShortcut("[", modifiers: .command)
            Divider()
            Button("Add or Remove Favourite") { model.toggleFavourite() }
                .keyboardShortcut("d", modifiers: .command)
            // ⌥⌘P is "play slideshow" in Keynote.
            Button("Church Mode") { model.enterChurchMode(from: .keyboard) }
                .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}
