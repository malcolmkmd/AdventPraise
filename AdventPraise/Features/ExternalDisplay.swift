//
//  ExternalDisplay.swift
//  Advent Praise
//
//  The worship display: church mode on a TV or projector. When one connects
//  (AirPlay or a cable), iOS hands the app an external display scene
//  (`UIWindowSceneSessionRoleExternalDisplayNonInteractive`); with Pro this
//  file gives it a window of its own with ExternalHymnView, a clean,
//  full-screen hymn on the brand ground that follows the phone: the verse
//  being sung, large, with the hymn's number and title and where the verse
//  is. No phone UI ever reaches it (no controls, no status bar, no
//  notifications). The phone is the remote: verses, next hymn, and Blank.
//
//  Without Pro the scene gets no window, so iOS mirrors the phone, and the
//  phone carries the Go Pro banner (ScreenMirroring.swift). Buying Pro with
//  the screen connected puts the worship display up at once; losing Pro (a
//  refund) takes it down.
//

import SwiftUI
import UIKit

/// Routes the external display role to its own scene delegate. Every other
/// role keeps SwiftUI's default configuration.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: session.configuration.name, sessionRole: session.role)
        if session.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return configuration
    }
}

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private weak var scene: UIWindowScene?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        self.scene = scene
        AppServices.shared.church.isExternalScreenConnected = true
        followPro()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window?.isHidden = true
        window = nil
        self.scene = nil
        AppServices.shared.church.isExternalScreenConnected = false
    }

    /// Shows or removes the worship display with Pro, now and whenever Pro changes.
    private func followPro() {
        let store = AppServices.shared.store
        let isPro = withObservationTracking { store.isPro } onChange: { [weak self] in
            Task { @MainActor in self?.followPro() }
        }
        if isPro { showWorshipDisplay() } else { removeWorshipDisplay() }
    }

    private func showWorshipDisplay() {
        guard window == nil, let scene else { return }
        let services = AppServices.shared
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: ExternalHymnView(model: services.reader, church: services.church)
            .environment(services.settings))
        host.view.backgroundColor = UIColor(WorshipDisplayGround.base)
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    /// No window: iOS goes back to mirroring the phone.
    private func removeWorshipDisplay() {
        window?.isHidden = true
        window = nil
    }
}

// MARK: - Worship display

/// The external screen: the brand ground, the hymn's words as large as the
/// room needs. Laid out for a 16:9 TV or projector; scales to any size.
struct ExternalHymnView: View {
    let model: ReaderModel
    let church: ChurchPresentation
    @Environment(ReadingSettings.self) private var settings

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(church.index) ? sequence[church.index] : nil }

    private enum Page: Hashable { case blank, verse(String), title(String) }

    private var page: Page {
        let hymnID = "\(model.hymnal.id)-\(model.hymn.id)"
        if church.isBlanked { return .blank }
        if church.isActive, block != nil { return .verse("\(hymnID)-\(church.index)") }
        return .title(hymnID)
    }

    var body: some View {
        GeometryReader { geo in
            // Laid out on a 1080-point-high screen and scaled to this one.
            let unit = geo.size.height / 1080
            ZStack {
                WorshipDisplayGround(unit: unit, showsMark: page == .blank)
                switch page {
                case .blank:
                    EmptyView()
                case .verse:
                    if let block { verse(block, unit: unit, in: geo.size).transition(.opacity) }
                case .title:
                    titleCard(unit: unit).transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: page)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .accessibilityHidden(true)   // VoiceOver is on the phone
    }

    // MARK: Verse

    private func verse(_ block: Hymn.Block, unit: CGFloat, in size: CGSize) -> some View {
        let isChorus: Bool = { if case .chorus = block { return true } else { return false } }()
        // 84 pt on 1080 at the phone's default size; the phone's text size
        // buttons scale it. A verse too long for the screen shrinks to fit.
        let phoneScale = settings.worshipPointSize / ReadingSettings.defaultWorshipPointSize
        let pointSize = 84 * unit * phoneScale * (settings.largePrint ? 1.15 : 1)
        let lyricFont = isChorus
            ? Font.custom(DS.ReadingFont.serif.chorusFace, fixedSize: pointSize * DS.ReadingFont.serif.chorusSizeRatio)
            : Font.system(size: pointSize, weight: .semibold, design: .serif)
        return VStack(spacing: 0) {
            header(unit: unit)
            Spacer(minLength: 32 * unit)
            VStack(spacing: 22 * unit) {
                if isChorus {
                    Text(model.hymnal.chorusLabel)
                        .font(.system(size: 26 * unit, weight: .bold)).tracking(4 * unit).textCase(.uppercase)
                        .foregroundStyle(DS.Palette.brassOnDark)
                }
                Text(block.lines.joined(separator: "\n"))
                    .font(lyricFont)
                    .lineSpacing(pointSize * DS.LineSpacing.compact.leading * DS.LyricScale.worship.leadingScale)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.3)
                    .shadow(color: .black.opacity(0.35), radius: 12 * unit, y: 2 * unit)
            }
            .frame(maxWidth: min(size.width * 0.88, pointSize * 24), maxHeight: .infinity)
            Spacer(minLength: 32 * unit)
            footer(unit: unit)
        }
        .padding(.horizontal, 96 * unit)
        .padding(.top, 64 * unit)
        .padding(.bottom, 56 * unit)
    }

    /// The number in brass beside the title, across the top.
    private func header(unit: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 22 * unit) {
            Text(String(model.hymn.id))
                .font(.system(size: 44 * unit, weight: .semibold, design: .serif)).monospacedDigit()
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(model.hymn.title)
                .font(.system(size: 36 * unit, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
    }

    /// Where the verse is: "Verse 2 of 4" and a dot for each block.
    private func footer(unit: CGFloat) -> some View {
        HStack(spacing: 22 * unit) {
            Rectangle().fill(DS.Palette.brassOnDark.opacity(0.35)).frame(height: 1)
            Text(position)
                .font(.system(size: 24 * unit, weight: .bold)).tracking(3 * unit).textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize()
            if sequence.count > 1, sequence.count <= 12 {
                HStack(spacing: 10 * unit) {
                    ForEach(sequence.indices, id: \.self) { index in
                        Circle()
                            .fill(index == church.index ? DS.Palette.brassOnDark : .white.opacity(0.28))
                            .frame(width: 11 * unit, height: 11 * unit)
                    }
                }
            }
            Rectangle().fill(DS.Palette.brassOnDark.opacity(0.35)).frame(height: 1)
        }
    }

    private var position: String {
        switch block {
        case let .verse(number, _)?: String(localized: "Verse \(number) of \(model.hymn.verseCount)")
        case .chorus?: model.hymnal.chorusLabel
        case nil: ""
        }
    }

    // MARK: Between hymns

    /// Church mode closed: the hymn about to be sung, as a title page.
    private func titleCard(unit: CGFloat) -> some View {
        VStack(spacing: 26 * unit) {
            SDALogoShape()
                .fill(WorshipDisplayGround.logoGradient, style: FillStyle(eoFill: true))
                .frame(width: 92 * unit, height: 92 * unit / SDALogoShape.aspectRatio)
                .opacity(0.9)
            Text(model.hymnal.name)
                .font(.system(size: 26 * unit, weight: .bold)).tracking(4 * unit).textCase(.uppercase)
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(String(model.hymn.id))
                .font(.system(size: 180 * unit, weight: .semibold, design: .serif)).monospacedDigit()
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(model.hymn.title)
                .font(.system(size: 76 * unit, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
        }
        .padding(120 * unit)
    }
}

/// The worship display's ground: Stage, lit from below with the brand's
/// evergreen and a little gold, like the paywall's light but still, so the
/// words keep full contrast. Blank shows only this and a faint mark.
struct WorshipDisplayGround: View {
    var unit: CGFloat = 1
    var showsMark = false

    static let base = DS.Palette.stage
    static let logoGradient = LinearGradient(
        colors: [Color(dsHex: 0xF3D68C), Color(dsHex: 0xE2B560), Color(dsHex: 0xB9892F)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Self.base
                RadialGradient(colors: [DS.Palette.evergreen.opacity(0.55), DS.Palette.evergreen.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 1.15), startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.75)
                RadialGradient(colors: [Color(dsHex: 0xE2B560).opacity(0.14), .clear],
                               center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0,
                               endRadius: geo.size.width * 0.4)
                if showsMark {
                    SDALogoShape()
                        .fill(Self.logoGradient, style: FillStyle(eoFill: true))
                        .frame(width: 140 * unit, height: 140 * unit / SDALogoShape.aspectRatio)
                        .opacity(0.16)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
/// `-uiDebugRenderExternal`: the worship display drawn at 1920 × 1080 to
/// PNGs, since the simulator's external display can't be scripted.
@MainActor
enum WorshipDisplayRenderer {
    static func render(model: ReaderModel, church: ChurchPresentation, settings: ReadingSettings, to prefix: String) {
        let saved = (church.isActive, church.index, church.isBlanked)
        let chorus = model.hymn.sungSequence.firstIndex { if case .chorus = $0 { true } else { false } }
        let pages: [(String, Bool, Int, Bool)] = [
            ("verse", true, 0, false),
            ("chorus", true, chorus ?? 0, false),
            ("title", false, 0, false),
            ("blank", true, 0, true),
        ]
        for (name, active, index, blanked) in pages {
            church.isActive = active
            church.index = index
            church.isBlanked = blanked
            let view = ExternalHymnView(model: model, church: church)
                .environment(settings)
                .frame(width: 1920, height: 1080)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: 1920, height: 1080)
            if let data = renderer.uiImage?.pngData() {
                try? data.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
            }
        }
        (church.isActive, church.index, church.isBlanked) = saved
    }
}
#endif
