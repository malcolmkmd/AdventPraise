//
//  HomeFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import HomeFeature
import HymnFeature
import ComposableArchitecture

public struct AppState: Equatable {
    
    var hymns: [Hymn] = [] {
        didSet {
            homeState.hymns = hymns
            homeState.activeHymnal = activeHymnal
        }
    }
    
    var homeState: HomeState
    var hymnState: HymnState
    var activeHymnal: Hymnal = .english
    
    enum ViewMode {
        case home, hymn 
    }
    
    var viewMode: ViewMode = .home
    
    public init(hymns: [Hymn],
                activeHymnal: Hymnal = .english) {
        self.hymns = hymns
        self.activeHymnal = activeHymnal
        self.homeState = HomeState(
            hymns: hymns,
            activeHymnal: activeHymnal)
        self.hymnState = HymnState()
    }
    
}

public enum AppAction: Equatable {
    case onLoad
    case home(action: HomeAction)
    case hymn(action: HymnAction)
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

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer<AppState, AppAction, AppEnvironment>.combine(homeReducer.pullback(
    state: \AppState.homeState,
    action: (/AppAction.home(action:)),
             environment: { _ in HomeEnvironment()}),
    hymnReducer.pullback(
        state: \AppState.hymnState,
        action: (/AppAction.hymn(action:)),
                 environment: { _ in HymnEnvironment()}),
        Reducer { state, action, environment in
            switch action {
                case .onLoad:
                    state.hymns = environment.loadHymns(state.activeHymnal)
                    return .none
                case .home(action: .presentHymn(let hymn)):
                    state.viewMode = .hymn
                    state.hymnState.activeHymn = hymn
                    return .none
                case .home(let action):
                    return .none
                case .hymn(action: .dismiss):
                    state.viewMode = .home
                    return .none
                case .hymn(let action):
                    return .none
            }
        })
