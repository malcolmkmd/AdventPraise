//
//  AdventPraisesApp.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

@main
struct AdventPraisesApp: App {
    
    @StateObject var store: Store = Store(
        initialState: AppState(),
        reducer: appReducer(state:action:))
    
    var body: some Scene {
        WindowGroup {
            RootTabBarView()
                .environmentObject(store)
        }
    }
}
