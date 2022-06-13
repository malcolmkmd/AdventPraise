//
//  AdventPraisesApp.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI
import Shared
import NumberPadFeature

@main
struct AdventPraisesApp: App {
    var body: some Scene {
        WindowGroup {
            NumberPadView(store: .init(
                initialState: NumberPadState(),
                reducer: numberPadReducer,
                environment: NumberPadEnvironment())).onAppear {
//                    NewYorkFont.registerFonts()
                }
        }
    }
}
