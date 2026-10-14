//
//  FeatureBoard.swift
//  Advent Praise
//
//  Vote on features: the Features.Vote board, a page in the More drawer.
//  The board itself is the SDK's VotingBoardView (its + is where a request
//  is made), painted with the reading surface's colours and type.
//
//  The first time, the page explains what leaves the phone before anything
//  loads; the board (and the SDK's first network call) waits for Continue.
//  Settings and the anonymous rules are in FeatureBoardConfig.
//

import SwiftUI
@preconcurrency import FeaturesVote

/// The SDK side. Configured once, on the first open, and only with a board.
@MainActor
enum FeatureBoard {
    private static var isConfigured = false

    /// Sets the SDK up for `surface`. False when there is no board.
    @discardableResult
    static func prepare(for surface: DSSurface) -> Bool {
        guard let slug = FeatureBoardConfig.slug else { return false }
        if !isConfigured {
            FeaturesVote.configure(with: slug)
            FeaturesVote.config = Configuration(
                ui: .init(showWatermark: FeatureBoardConfig.showWatermark),
                behavior: .init(
                    allowAnonymousVoting: FeatureBoardConfig.allowAnonymousVoting,
                    allowAnonymousComments: FeatureBoardConfig.allowAnonymousComments,
                    requireEmailForCreate: FeatureBoardConfig.requireEmailForCreate
                )
            )
            var words = Localization.default
            words.votingBoardTitle = String(localized: "Vote on features")
            words.createFeatureTitle = String(localized: "Request a feature")
            FeaturesVote.localization = words
            // Anonymous: no updateUser, setToken or custom id, ever.
            FeaturesVote.updateMetadata(FeatureBoardConfig.metadata(appVersion: AppInfo.version))
            isConfigured = true
        }
        FeaturesVote.theme = theme(for: surface)
        return true
    }

    /// The board in the reading surface's colours and Vesper type.
    private static func theme(for surface: DSSurface) -> Theme {
        Theme(
            primaryColor: surface.tint,
            secondaryColor: surface.brass,
            backgroundColor: surface.background,
            surfaceColor: surface.elevated,
            textPrimaryColor: surface.foreground,
            textSecondaryColor: surface.secondary,
            titleFont: DS.Typeface.rowTitle,
            bodyFont: DS.Typeface.rowBody,
            captionFont: DS.Typeface.detail,
            cornerRadius: DS.Radius.tile
        )
    }
}

// MARK: - Page

/// Vote on features, a page in the More drawer that fills it: the board has
/// its own list (and its own navigation, for a feature's comments). Back is
/// the drawer's.
struct FeatureBoardPage: View {
    @Environment(\.dsSurface) private var surface
    @State private var showsBoard = FeatureBoardConfig.hasDisclosed()
    @State private var openedAt = ContinuousClock.now

    var body: some View {
        Group {
            if showsBoard {
                FeaturesVote.VotingBoardView()
                    .transition(.opacity)
            } else {
                DrawerAwareScrollView { disclosure }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            openedAt = .now
            Analytics.track(.featureBoardOpened(disclosed: showsBoard))
        }
        .onDisappear {
            let seconds = Int((ContinuousClock.now - openedAt).components.seconds)
            Analytics.track(.featureBoardClosed(seconds: seconds, showedBoard: showsBoard))
        }
        .analyticsScreen(.featureBoard)
    }

    /// First open only: what the board sends, before it sends anything.
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            Image(systemName: "lightbulb")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(surface.brass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("Vote on features")
                    .font(DS.Typeface.sheetTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("See what others have asked for, vote for the ones you want, or request your own.")
                    .font(DS.Typeface.rowBody)
                Text("Requests, comments and votes go to Features.Vote, which runs the board, with a random ID for this phone. Your name and email aren't sent, so please don't type them in.")
                    .font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            GlassButton(title: "Continue", fullWidth: true) {
                FeatureBoardConfig.markDisclosed()
                Analytics.track(.featureBoardDisclosureAccepted)
                Haptics.play(.lightImpact)
                withAnimation(DS.Motion.select) { showsBoard = true }
            }
        }
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.bottom, DS.Space.l)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}
