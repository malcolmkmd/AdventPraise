//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import CoreUI
import SwiftUI
import SearchFeature
import NumberPadFeature
import HymnalPickerFeature
import ComposableArchitecture

public struct AppView: View {
    
    let store: Store<AppState, AppAction>
    
    public init(store: Store<AppState, AppAction>) {
        self.store = store
        ViewStore(store).send(.onLoad)
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                switch viewStore.viewMode {
                    case .number:
                        NumberPadView(store: store.scope(
                            state: \.numberPadState,
                            action: AppAction.number(action:)))
                    case .search:
                        SearchView(store: store.scope(
                            state: \.searchState,
                            action: AppAction.search(action:)))
                    case .hymnPicker:
                        HymnalPickerView(store: store.scope(state: \.hymnalPickerState, action: AppAction.hymnalPicker(action:)))
                }
            }
        }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        AppView(store: .init(initialState: AppState(hymns: HymnalClient.mockHymns()), reducer: appReducer, environment: .live)).loadCustomFonts()
    }
}
#endif
