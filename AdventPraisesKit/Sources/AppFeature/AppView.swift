//
//  HomeView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SwiftUI
import HomeFeature
import HymnalPickerFeature
import ComposableArchitecture

public struct AppView: View {
    
    @Namespace var numberToSearch
    let store: Store<AppState, AppAction>
    
    public init(store: Store<AppState, AppAction>) {
        self.store = store
        CustomFonts.registerFonts()
        ViewStore(store).send(.onLoad)
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                switch viewStore.viewMode {
                    case .number:
                        HomeView(store: store.scope(
                            state: \.homeState,
                            action: AppAction.number(action:)),
                            namespace: numberToSearch)
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
