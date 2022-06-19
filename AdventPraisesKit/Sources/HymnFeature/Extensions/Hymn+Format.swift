//
//  Hymn.swift
//  
//
//  Created by Malcolm on 6/19/22.
//

import Core
import SwiftUI

extension Hymn {
    public var markdown: AttributedString {
        guard let text = try? AttributedString(
            markdown: normalFormat,
            including: \.hymnStyle,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        else {
            return AttributedString(lyrics)
        }
        return text
    }
    
    var normalFormat: String {
        lyrics
            .replacing(chorus, with: "^[\(chorus)](style: 'italic')")
    }
    
    var continousFormat: String {
        guard normalFormat.contains("CHORUS") else { return normalFormat }
        let verseChunks = normalFormat
            .replacing("^[CHORUS](style: 'bold')", with: "")
            .replacing("^[\(chorus)](style: 'italic')", with: "")
            .components(separatedBy: "\n\n")
            .filter { $0 != "" }
        var continousChunks: [String] = []
        for chunk in verseChunks {
            continousChunks.append("\n\n\(chunk)\n\n ^[CHORUS](style: 'bold') \n \(chorus)"
                .replacing(chorus, with: "^[\(chorus)](style: 'italic')")
            )
        }
        let continuosText = continousChunks.reduce("",+)
        if continuosText.contains("^") || continuosText.contains("[") {
            return normalFormat
        }
        return continuosText
    }
    
    var chorus: String {
        lyrics.slice(from: "\n\n^[CHORUS](style: 'bold')\n", to: "\n\n") ?? ""
    }
}
