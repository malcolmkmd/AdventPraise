//
//  ExternalDisplay.swift
//  Advent Praise
//
//  Church mode on a second screen. When a TV or projector connects (AirPlay
//  or a cable), iOS hands the app an external display scene; this file
//  gives it a window with ExternalHymnView, a clean full-screen hymn that
//  follows the phone: the verse being sung, at the phone's chosen size
//  scaled to the screen. The phone stays the remote.
//
//  Pro only. Without Pro the screen shows what Pro would put there, and if
//  church mode is open the phone shows the paywall.
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

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let services = AppServices.shared
        let window = UIWindow(windowScene: scene)
        let root = ExternalHymnView(model: services.reader, church: services.church)
            .environment(services.settings)
            .environment(services.store)
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .black
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        services.church.isExternalScreenConnected = true
        if services.church.isActive, !services.store.isPro { services.reader.paywall = .airPlay }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        AppServices.shared.church.isExternalScreenConnected = false
    }
}

/// The external screen: black, the hymn's words as large as the room needs.
struct ExternalHymnView: View {
    let model: ReaderModel
    let church: ChurchPresentation
    @Environment(ReadingSettings.self) private var settings
    @Environment(PurchaseStore.self) private var store

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(church.index) ? sequence[church.index] : nil }

    var body: some View {
        GeometryReader { geo in
            // The phone's size, scaled from a phone's height (≈ 850 pt) to this screen's.
            let scale = max(geo.size.height / 850, 1)
            ZStack {
                Color.black
                if !store.isPro {
                    proCard(scale: scale)
                } else if church.isActive, let block {
                    verse(block, scale: scale, in: geo.size)
                        .id("\(model.hymnal.id)-\(model.hymn.id)-\(church.index)")
                        .transition(.opacity)
                } else {
                    titleCard(scale: scale)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: church.index)
            .animation(.easeInOut(duration: 0.35), value: model.hymn.id)
            .animation(.easeInOut(duration: 0.35), value: church.isActive)
        }
        .ignoresSafeArea()
        .dsSurface(.black, paintsBackground: false)
        .environment(\.colorScheme, .dark)
        .foregroundStyle(DSSurface.black.highContrastForeground)
        .accessibilityHidden(true)   // VoiceOver is on the phone
    }

    // MARK: Verse

    private func verse(_ block: Hymn.Block, scale: CGFloat, in size: CGSize) -> some View {
        let isChorus: Bool = { if case .chorus = block { return true } else { return false } }()
        let pointSize = settings.worshipPointSize * scale * (settings.largePrint ? 1.2 : 1)
        let lyricFont = isChorus
            ? Font.custom(DS.ReadingFont.serif.chorusFace, fixedSize: pointSize * DS.ReadingFont.serif.chorusSizeRatio)
            : Font.system(size: pointSize, weight: .semibold, design: .serif)
        return VStack(spacing: 0) {
            header(scale: scale)
                .frame(maxWidth: size.width * 0.8)
            Spacer(minLength: 24 * scale)
            VStack(spacing: 14 * scale) {
                if isChorus {
                    Text(model.hymnal.chorusLabel)
                        .font(.system(size: 15 * scale, weight: .bold)).tracking(2 * scale).textCase(.uppercase)
                        .foregroundStyle(DS.Palette.brassOnDark)
                }
                // Never scrolls: a verse too long for the screen shrinks to fit.
                Text(block.lines.joined(separator: "\n"))
                    .font(lyricFont)
                    .lineSpacing(pointSize * DS.LineSpacing.compact.leading * DS.LyricScale.worship.leadingScale)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.35)
            }
            .frame(maxWidth: min(size.width * 0.86, pointSize * 22))
            Spacer(minLength: 24 * scale)
            Text(position)
                .font(.system(size: 14 * scale, weight: .bold)).tracking(1.4 * scale).textCase(.uppercase)
                .foregroundStyle(DSSurface.black.secondary)
        }
        .padding(.horizontal, 48 * scale)
        .padding(.vertical, 32 * scale)
    }

    /// The number over the full title: a long title wraps (balanced, centred)
    /// rather than being cut off.
    private func header(scale: CGFloat) -> some View {
        VStack(spacing: 4 * scale) {
            Text(String(model.hymn.id))
                .font(.system(size: 22 * scale, weight: .semibold, design: .serif)).monospacedDigit()
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(model.hymn.title)
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundStyle(DSSurface.black.secondary)
                .lineLimit(2)
                .dsBalancedWrap()
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
    private func titleCard(scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            Text(model.hymnal.name)
                .font(.system(size: 15 * scale, weight: .bold)).tracking(2 * scale).textCase(.uppercase)
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(String(model.hymn.id))
                .font(.system(size: 96 * scale, weight: .semibold, design: .serif)).monospacedDigit()
                .foregroundStyle(DS.Palette.brassOnDark)
            Text(model.hymn.title)
                .font(.system(size: 44 * scale, weight: .semibold, design: .serif))
                .dsBalancedWrap()
        }
        .padding(64 * scale)
    }

    // MARK: Without Pro

    private func proCard(scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            Image(systemName: "airplayvideo")
                .font(.system(size: 56 * scale, weight: .semibold))
                .foregroundStyle(DS.Palette.brassOnDark)
            Text("Advent Praise Pro")
                .font(.system(size: 15 * scale, weight: .bold)).tracking(2 * scale).textCase(.uppercase)
                .foregroundStyle(DS.Palette.brassOnDark)
            Text("Show the words here, full screen, and turn the verses from your phone.")
                .font(.system(size: 32 * scale, weight: .semibold, design: .serif))
                .dsBalancedWrap()
        }
        .padding(64 * scale)
        .frame(maxWidth: 900 * scale)
    }
}
