//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/19/22.
//

import SwiftUI

public struct HymnText: View {
    private var attributedString: AttributedString
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(attributedString)
                .padding(.horizontal)
                .font(.customBody)
        }
        .frame(minWidth: UIScreen.main.bounds.width)
        .background(Color.clear)
    }
    
    public init(_ attributedString: AttributedString) {
        self.attributedString = HymnText.annotate(from: attributedString)
    }
    
    private static func annotate(from source: AttributedString) -> AttributedString {
        var attrString = source
        for run in attrString.runs {
            guard let style = run.style else {
                continue
            }
            let currentRange = run.range
            var index = currentRange.lowerBound
            while index < currentRange.upperBound {
                let nextIndex = attrString.characters.index(index, offsetBy: 1)
                switch style {
                    case .bold:
                        attrString[index ..< nextIndex].font = .customHeadline
                    case .italic:
                        attrString[index ..< nextIndex].font = .customHeadline
                }
                index = nextIndex
            }
        }
        return attrString
    }
}


enum HymnTextAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    enum Value: String, Codable, Hashable {
        case bold
        case italic
    }
    
    static var name: String = "style"
}

extension AttributeScopes {
    struct HymnStyleAttributes: AttributeScope {
        let style: HymnTextAttribute
    }
    
    var hymnStyle: HymnStyleAttributes.Type { HymnStyleAttributes.self }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.HymnStyleAttributes, T>) -> T {
        self[T.self]
    }
}
