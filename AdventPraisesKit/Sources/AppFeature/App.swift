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
    
    var homeState: HomeState
    var hymnState: HymnState
    var activeHymnal: Hymnal = .english
    
    enum ViewMode {
        case home, hymn 
    }
    
    var viewMode: ViewMode = .home
    
    public init(activeHymnal: Hymnal = .english) {
        self.activeHymnal = activeHymnal
        self.homeState = HomeState(activeHymnal: activeHymnal)
        self.hymnState = HymnState(
            activeHymnal: activeHymnal,
            activeHymn: activeHymnal.hymns[0])
    }
    
}

public enum AppAction: Equatable {
    case onLoad
    case home(action: HomeAction)
    case hymn(action: HymnAction)
}

public struct AppEnvironment {
    var storage: Storage
    
    public init(storage: Storage = Storage()) {
        self.storage = storage
    }
    
}

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer<AppState, AppAction, AppEnvironment>.combine(homeReducer.pullback(
    state: \AppState.homeState,
    action: (/AppAction.home(action:)),
             environment: { appEnvironment in
                 HomeEnvironment(storage: appEnvironment.storage)
             }),
    hymnReducer.pullback(
        state: \AppState.hymnState,
        action: (/AppAction.hymn(action:)),
                 environment: { _ in HymnEnvironment()}),
        Reducer { state, action, environment in
            switch action {
                case .onLoad:
                    state.activeHymnal = Hymnal(rawValue: environment.storage.selectedHymnalId) ?? .english
                    return .none
                case .home(action: .presentHymn(let hymn)):
                    state.viewMode = .hymn
                    state.hymnState = HymnState(
                        activeHymnal: state.activeHymnal,
                        activeHymn: hymn)
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
