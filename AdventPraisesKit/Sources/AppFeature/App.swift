//
//  HomeFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import HomeFeature
import HymnalPickerFeature
import ComposableArchitecture

public struct AppState: Equatable {
    
    var hymns: [Hymn] = [] {
        didSet {
            homeState.hymns = hymns
            homeState.activeHymnal = activeHymnal
        }
    }
    
    var homeState: HomeState
    var hymnalPickerState: HymnalPickerState
    var activeHymnal: Hymnal = .english
    
    
    enum ViewMode {
        case number, hymnPicker
    }
    
    var viewMode: ViewMode = .number
    var previousMode: ViewMode = .number
    
    
    public init(hymns: [Hymn],
                activeHymnal: Hymnal = .english) {
        self.hymns = hymns
        self.activeHymnal = activeHymnal
        self.homeState = HomeState(
            hymns: hymns,
            activeHymnal: activeHymnal)
        self.hymnalPickerState = HymnalPickerState(
            activeHymnal: activeHymnal)
    }
    
}

public enum AppAction: Equatable {
    case onLoad
    case number(action: HomeAction)
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

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer<AppState, AppAction, AppEnvironment>.combine(homeReducer.pullback(
    state: \AppState.homeState,
    action: (/AppAction.number(action:)),
             environment: { _ in HomeEnvironment()}),
    hymnalPickerReducer.pullback(
        state: \AppState.hymnalPickerState,
        action: (/AppAction.hymnalPicker(action:)),
                 environment: { _ in HymnalPickerEnvironment() }),
        Reducer { state, action, environment in
            switch action {
                case .onLoad:
                    state.hymns = environment.loadHymns(state.activeHymnal)
                    return .none
                case .number(action: .didTapHymnPicker):
                    state.viewMode = .hymnPicker
                    state.previousMode = .number
                    return .none
                case .number(let action):
                    return .none
                case .hymnalPicker(action: .dismiss):
                    state.viewMode = state.previousMode
                    return .none
            }
        })
