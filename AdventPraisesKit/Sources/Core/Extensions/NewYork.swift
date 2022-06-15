//
//  NewYork.swift
//  
//
//  Created by Malcolm on 6/13/22.
//

import SwiftUI

public enum NewYorkFont: String, CaseIterable {
    
    case bold = "NewYorkItalic"
    case regular = "NewYork"
//    case black = "New York Black"
//    case semiBold = "New York Semi Bold"
    
//    public static func registerFonts() {
//        NewYorkFont.allCases.forEach {
//            registerFont(
//                bundle: .module,
//                fontName: $0.rawValue,
//                fontExtension: "ttf")
//        }
//    }
    
    private static func registerFont(bundle: Bundle,
                                     fontName: String,
                                     fontExtension: String) {
        // Find font convert to core graphics provider.
        guard
            let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
            let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
            let font = CGFont(fontDataProvider)
        else {
            fatalError("Couldn't create font from filename: \(fontName) with extension \(fontExtension)")
        }
        
        // Register font with core graphics.
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
        print(UIFont.familyNames)
    }
    
}

extension Font.TextStyle {
    public var size: CGFloat {
        switch self {
            case .largeTitle: return 60
            case .title: return 48
            case .title2: return 34
            case .title3: return 24
            case .headline, .body: return 18
            case .subheadline, .callout: return 16
            case .footnote: return 14
            case .caption, .caption2: return 12
            @unknown default:
                return 8
        }
    }
}

public extension Font {
    
//    static let apBody = custom(.regular, relativeTo: .title)
//    static let apRegular = custom(.regular, relativeTo: .body)
//    static let apLargeTitle = custom(.bold, relativeTo: .largeTitle)
    
    static func custom(_ font: NewYorkFont,
                       relativeTo style: Font.TextStyle) -> Font {
        custom(font.rawValue, size: style.size, relativeTo: style)
    }
}

