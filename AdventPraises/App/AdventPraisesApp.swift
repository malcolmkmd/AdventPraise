//
//  AdventPraisesApp.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Shared
import SwiftUI
import NumberPadFeature

@main
struct AdventPraisesApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(store: .init(
                initialState: HomeState(
                    numberPadState: NumberPadState(),
                    searchState: SearchState(allHymns: HymnManager.loadJsonHymns())),
                reducer: homeReducer,
                environment: .live))
        }
    }
}
