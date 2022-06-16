import SwiftUI

extension Font {
    public static let largeTitleCustom = Font.custom("JetBrainsMono-Medium", size: 34, relativeTo: .largeTitle)
    public static let titleCustom = Font.custom("JetBrainsMono-ExtraBold", size: 28, relativeTo: .title)
    public static let title2Custom = Font.custom("JetBrainsMono-Medium", size: 22, relativeTo: .title2)
    public static let title3Custom = Font.custom("JetBrainsMono-Medium", size: 20, relativeTo: .title3)
    public static let headlineCustom = Font.custom("JetBrainsMono-Medium", size: 17, relativeTo: .headline)
    public static let subheadlineCustom = Font.custom("JetBrainsMono-Medium", size: 15, relativeTo: .subheadline)
    public static let bodyCustom = Font.custom("JetBrainsMono-ExtraBold", size: 17, relativeTo: .body)
    public static let calloutCustom = Font.custom("JetBrainsMono-Medium", size: 16, relativeTo: .callout)
    public static let footnoteCustom = Font.custom("JetBrainsMono-Medium", size: 13, relativeTo: .footnote)
    public static let captionCustom = Font.custom("JetBrainsMono-Medium", size: 12, relativeTo: .caption)
    public static let caption2Custom = Font.custom("JetBrainsMono-Medium", size: 11, relativeTo: .caption2)
}

public enum CustomFonts: String, CaseIterable {
    
    case jetBold = "JetBrainsMono-Bold"
    case jetLight = "JetBrains-Light"
    case jetMedium = "JetBrainsMono-Medium"
    case jetExtraBold = "JetBrainsMono-ExtraBold"
    case jetMediumItalic = "JetBrainsMono-MediumItalic"
    
    public static func registerFonts() {
        CustomFonts.allCases.forEach {
            registerFonts(
                font: "\($0.rawValue).ttf")
        }
    }
    
    private static func registerFonts(font: String) {
        guard let url = Bundle.coreUI.url(forResource: font, withExtension: nil) else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension View {
    /// Attach this to any Xcode Preview's view to have custom fonts displayed
    /// Note: Not needed for the actual app
    public func loadCustomFonts() -> some View {
        CustomFonts.registerFonts()
        return self
    }
}

