//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Shared
import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
    
    let store: Store<HomeState, HomeAction>
    
    public init(store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                if !viewStore.isSearchPresented {
                    NumberPadView(store: store.scope(
                        state: \.numberPadState,
                        action: HomeAction.number(action:)))
                } else {
                    SearchView(store: store.scope(
                        state: \.searchState,
                        action: HomeAction.search(action:)))
                }
            }.onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(
            initialState: HomeState(
                numberPadState: NumberPadState(),
                searchState: SearchState(allHymns: HymnManager.loadJsonHymns(for: .english))),
            reducer: homeReducer,
            environment: .live))
    }
}
#endif
