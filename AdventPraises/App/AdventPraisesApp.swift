//
//  AdventPraisesApp.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import CoreUI
import SwiftUI
import AppFeature
import HymnalPickerFeature

@main
struct AdventPraisesApp: App {
    
    var body: some Scene {
        WindowGroup {
            AppView(store: .init(
                initialState: AppState(hymns: HymnalClient.loadJsonHymns()),
                reducer: appReducer,
                environment: .live))
        }
    }
    
}

#if DEBUG
struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppView(store: .init(
                initialState: AppState(hymns: HymnalClient.loadJsonHymns()),
                reducer: appReducer,
                environment: .live))
        }.previewDevice("iPhone SE")
    }
}
#endif
