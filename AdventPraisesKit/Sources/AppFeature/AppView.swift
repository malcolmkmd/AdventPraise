//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SwiftUI
import HomeFeature
import HymnFeature
import ComposableArchitecture

public struct AppView: View {
    
    let store: Store<AppState, AppAction>
    
    public init(store: Store<AppState, AppAction>) {
        self.store = store
        CustomFonts.registerFonts()
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                switch viewStore.viewMode {
                    case .home:
                        HomeView(store.scope(
                            state: \.homeState,
                            action: AppAction.home(action:)))
                    case .hymn:
                        HymnView(store.scope(
                            state: \.hymnState,
                            action: AppAction.hymn(action:)))
                }
            }.onAppear {
                viewStore.send(.onLoad)
            }
        }
    }
}

