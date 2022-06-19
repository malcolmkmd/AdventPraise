//
//  File.swift
//
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public struct Hymn: Equatable, Identifiable, Decodable {
    public var id: String
    public let title: String
    public let subtitle: String
    public let lyrics: String
    
    public init(id: String = "",
                title: String,
                subtitle: String,
                lyrics: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.lyrics = lyrics
    }
    
    enum CodingKeys: CodingKey {
        case id
        case title
        case subtitle
        case lyrics
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = String((decoder.codingPath.first!.intValue ?? 0) + 1)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.lyrics = try container.decode(String.self, forKey: .lyrics)
    }
    
    public func attributedMarkDown() -> AttributedString {
        var attributedString = AttributedString("")
        do {
            attributedString = try AttributedString(
                markdown: lyrics,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch let error {
            print(error)
        }
        return attributedString
    }
}

extension String {
    
    public func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
    
    public func sliceMultipleTimes(from: String, to: String) -> [String] {
        components(separatedBy: from).dropFirst().compactMap { sub in
            (sub.range(of: to)?.lowerBound).flatMap { endRange in
                String(sub[sub.startIndex ..< endRange])
            }
        }
    }
    
}
