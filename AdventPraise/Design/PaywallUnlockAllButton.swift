//
//  PaywallUnlockAllButton.swift
//  Advent Praise 7 — Vesper design system
//
//  Closes LanguagePicker's list while hymnals are sold. Every hymnal is free
//  from 7.0, so the app passes `ownsEverything` and it isn't shown.
//

import SwiftUI

/// The "Unlock all N hymnals" call to action that closes the paywall list.
struct PaywallUnlockAllButton: View {
    let count: Int
    let price: String?
    var isPurchasing = false
    let action: () -> Void

    var body: some View {
        GlassButton(title: title, systemImage: "lock.open.fill", isLoading: isPurchasing,
                    fullWidth: true, action: action)
            .disabled(isPurchasing || price == nil)
    }

    private var title: LocalizedStringKey {
        if let price { "Unlock all \(count) hymnals · \(price)" } else { "Unlock all \(count) hymnals" }
    }
}
