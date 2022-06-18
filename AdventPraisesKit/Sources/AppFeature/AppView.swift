//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SwiftUI
import HomeFeature
import LanguagePickerFeature
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
                        HomeView(store: store.scope(
                            state: \.homeState,
                            action: AppAction.home(action:)))
                }
            }.onAppear {
                viewStore.send(.onLoad)
            }
        }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        AppView(store: .init(initialState: AppState(hymns: HymnalClient.mockHymns()), reducer: appReducer, environment: .live))
            .loadCustomFonts()
    }
}
#endif
