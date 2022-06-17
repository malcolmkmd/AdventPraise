import SwiftUI

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
        guard let url = Bundle.core.url(forResource: font, withExtension: nil) else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    /// ExtraBold 34
    public static let customLargeTitle = CustomFont(.jetExtraBold, size: 34, relativeTo: .largeTitle)
    /// ExtraBold 34
    public static let customTitle = CustomFont(.jetExtraBold, size: 28, relativeTo: .title)
    /// ExtraBold 34
    public static let customTitle2 = CustomFont(.jetExtraBold, size: 22, relativeTo: .title2)
    /// ExtraBold 20
    public static let customTitle3 = CustomFont(.jetExtraBold, size: 20, relativeTo: .title3)
    /// Bold 18
    public static let customHeadline = CustomFont(.jetBold, size: 18, relativeTo: .headline)
    /// Bold 16
    public static let customSubheadline = CustomFont(.jetBold, size: 16, relativeTo: .subheadline)
    /// Medium 16
    public static let customBody = CustomFont(.jetMedium, size: 16, relativeTo: .body)
    /// MediumItalic 16
    public static let customBodyItalic = CustomFont(.jetMediumItalic, size: 16, relativeTo: .body)
    /// Medium 16
    public static let customCallout = CustomFont(.jetMedium, size: 16, relativeTo: .callout)
    /// Medium 14
    public static let customFootnote = CustomFont(.jetMedium, size: 14, relativeTo: .footnote)
    /// Light 12
    public static let customCaption = CustomFont(.jetLight, size: 12, relativeTo: .caption)
    /// Light 11
    public static let customCaption2 = CustomFont(.jetLight, size: 11, relativeTo: .caption2)
    
    static func CustomFont(_ font: CustomFonts,
                           size: CGFloat,
                           relativeTo textStyle: Font.TextStyle) -> Font {
        Font.custom(font.rawValue, size: size, relativeTo: textStyle)
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

