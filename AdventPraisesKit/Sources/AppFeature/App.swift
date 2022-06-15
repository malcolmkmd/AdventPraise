//
//  HomeFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import SearchFeature
import NumberPadFeature
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
    var activeHymnal: Hymnal = .english
    var isSearchPresented: Bool = false
    
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
    }
    
}

public enum AppAction: Equatable {
    case onLoad
    case search(action: SearchAction)
    case number(action: NumberPadAction)
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
    searchReducer.pullback(
        state: \AppState.searchState,
        action: (/AppAction.search(action:)),
                 environment: { _ in SearchEnvironment() }),
        Reducer { state, action, environment in
            switch action {
                case .onLoad:
                    state.hymns = environment.loadHymns(state.activeHymnal)
                    return .none
                case .number(action: .changeHymnal(let hymnal)):
                    state.activeHymnal = hymnal
                    state.hymns = environment.loadHymns(state.activeHymnal)
                    return .none
                case .number(action: .setSearch(isPresented: let isPresented)):
                    state.isSearchPresented = isPresented
                    return .none
                case .number(let action):
                    return .none
                case .search(action: .dismiss):
                    state.isSearchPresented = false
                    return .none
                case .search(action: let action):
                    return .none
            }
        })
