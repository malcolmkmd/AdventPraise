//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/19/22.
//

import SwiftUI
import ComposableArchitecture

public struct HymnText: View {
    
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView(.vertical, showsIndicators: false) {
                Text(annotate(
                    from: viewStore.activeHymn.markdown,
                    fontName: viewStore.fontName,
                    fontSize: viewStore.fontSize))
                .foregroundColor(viewStore.theme.textColor)
                .font(Font.custom(
                    viewStore.fontName,
                    fixedSize: viewStore.fontSize))
                .lineSpacing(viewStore.lineSpacing.size)
                .padding(.horizontal)
            }
            .frame(minWidth: UIScreen.main.bounds.width)
            .background(Color.clear)
        }
       
    }
    
    private func annotate(from source: AttributedString,
                          fontName: String,
                          fontSize: CGFloat) -> AttributedString {
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
                        attrString[index ..< nextIndex].font = Font.custom(
                            fontName,
                            fixedSize: fontSize + 2)
                        .weight(.bold)
                    case .italic:
                        attrString[index ..< nextIndex].font = Font.custom(
                            fontName,
                            fixedSize: fontSize + 2)
                        .weight(.bold)
                        .italic()
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
