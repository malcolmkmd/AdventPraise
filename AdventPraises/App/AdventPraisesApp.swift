//
//  AdventPraisesApp.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import SwiftUI
import AppFeature

@main
struct AdventPraisesApp: App {
    
    var body: some Scene {
        WindowGroup {
            AppView(store: .init(
                initialState: AppState(),
                reducer: appReducer,
                environment: AppEnvironment()))
        }
    }
    
}
