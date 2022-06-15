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
    
    init() {
        NewYorkFont.registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView(store: .init(
                initialState: AppState(hymns: HymnalClient.loadJsonHymns()),
                reducer: appReducer,
                environment: .live))
            .font(.custom(.bold, relativeTo: .title))
        }
    }
    
}
