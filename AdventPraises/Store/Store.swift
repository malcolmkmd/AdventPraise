//
//  Store.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Foundation

final class Store: ObservableObject {
    
    @Published private(set) var state: AppState
    
    private let reducer: Reducer<AppState, AppAction>
    
    init(initialState: AppState,
         reducer: @escaping Reducer<AppState, AppAction>) {
        self.state = initialState
        self.reducer = reducer
    }
    
    func send(_ action: AppAction) {
        reducer(&state, action)
    }
    
}

extension Store {
    static let live = Store(
        initialState: AppState(),
        reducer: appReducer(state:action:))
}
