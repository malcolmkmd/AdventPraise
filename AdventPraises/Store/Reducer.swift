//
//  Reducer.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Foundation

typealias Reducer<State, Action> = (inout State, Action) -> Void

func appReducer(state: inout AppState, action: AppAction) {
    switch action {
        case .didSelect(let tab):
            state.selectedTab = tab
        case .didPress(let item):
            switch item {
                case .delete:
                    state.activeNumber = String(state.activeNumber.dropLast())
                case .number(let value):
                    guard state.activeNumber.count != 3 else { return }
                    state.activeNumber = state.activeNumber + "\(value)"
                case .empty: return
            }
        case .didLongPress(let item):
            if item == .delete {
                state.activeNumber = ""
            }
    }
}
