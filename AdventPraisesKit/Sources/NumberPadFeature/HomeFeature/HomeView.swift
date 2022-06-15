//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
    
    let store: Store<AppState, AppAction>
    
    public init(store: Store<AppState, AppAction>) {
        self.store = store
        ViewStore(store).send(.onLoad)
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                if !viewStore.isSearchPresented {
                    NumberPadView(store: store.scope(
                        state: \.numberPadState,
                        action: AppAction.number(action:)))
                } else {
                    SearchView(store: store.scope(
                        state: \.searchState,
                        action: AppAction.search(action:)))
                }
            }
        }
    }
}

#if DEBUG
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(store: .init(
//            initialState: AppState(
//                numberPadState: NumberPadState(),
//                searchState: SearchState(allHymns: HymnManager.loadJsonHymns(for: .english))),
//            reducer: appReducer,
//            environment: .live))
//    }
//}
#endif
