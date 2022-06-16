//
//  HomeFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SearchFeature
import NumberPadFeature
import HymnalPickerFeature
import ComposableArchitecture

public struct AppState: Equatable {
    
    var hymns: [Hymn] = [] {
        didSet {
            searchState.hymns = hymns
            searchState.activeHymnal = activeHymnal
            numberPadState.hymns = hymns
            numberPadState.activeHymnal = activeHymnal
        }
    }
    
    var searchState: SearchState
    var numberPadState: NumberPadState
    var hymnalPickerState: HymnalPickerState
    var activeHymnal: Hymnal = .english
    
    
    enum ViewMode {
        case number, search, hymnPicker
    }
    
    var viewMode: ViewMode = .number
    var previousMode: ViewMode = .number
    
    
    public init(hymns: [Hymn],
                activeHymnal: Hymnal = .english) {
        self.hymns = hymns
        self.activeHymnal = activeHymnal
        self.searchState = SearchState(
            hymns: hymns,
            activeHymnal: activeHymnal)
        self.numberPadState = NumberPadState(
            hymns: hymns,
            activeHymnal: activeHymnal)
        self.hymnalPickerState = HymnalPickerState(
            activeHymnal: activeHymnal)
    }
    
}

public enum AppAction: Equatable {
    case onLoad
    case search(action: SearchAction)
    case number(action: NumberPadAction)
    case hymnalPicker(action: HymnalPickerAction)
}

public struct AppEnvironment {
    var loadHymns: (Hymnal) -> [Hymn]
}

public extension AppEnvironment {
    static let live = Self(loadHymns: { vernacular in
        HymnalClient.loadJsonHymns(for: vernacular)
    })
    
    static let preview = Self(loadHymns: { vernacular in
        HymnalClient.mockHymns(for: vernacular)
    })
}

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer<AppState, AppAction, AppEnvironment>.combine(numberPadReducer.pullback(
    state: \AppState.numberPadState,
    action: (/AppAction.number(action:)),
             environment: { _ in NumberPadEnvironment()}),
    hymnalPickerReducer.pullback(
        state: \AppState.hymnalPickerState,
        action: (/AppAction.hymnalPicker(action:)),
                 environment: { _ in HymnalPickerEnvironment() }),
    searchReducer.pullback(
        state: \AppState.searchState,
        action: (/AppAction.search(action:)),
                 environment: { _ in SearchEnvironment() }),
        Reducer { state, action, environment in
            switch action {
                case .onLoad:
                    state.hymns = environment.loadHymns(state.activeHymnal)
                    return .none
                case .number(action: .didTapHymnPicker):
                    state.viewMode = .hymnPicker
                    state.previousMode = .number
                    return .none
                case .search(action: .didTapHymnPicker):
                    state.viewMode = .hymnPicker
                    state.previousMode = .search
                    return .none
                case .number(action: .didTapSearchField):
                    state.viewMode = .search
                    return .none
                case .number(let action):
                    return .none
                case .hymnalPicker(action: .dismiss):
                    state.viewMode = state.previousMode
                    return .none
                case .search(action: .dismiss):
                    state.viewMode = .number
                    return .none
                case .search(action: let action):
                    return .none
            }
        })
