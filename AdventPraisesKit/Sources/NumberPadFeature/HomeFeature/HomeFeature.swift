//
//  HomeFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Shared
import ComposableArchitecture

public struct HomeState: Equatable {
    var hymns: [Hymn] = []
    var searchState: SearchState
    var numberPadState: NumberPadState
    var currentVernacular: Vernacular = .english
    var isSearchPresented: Bool = false
    
    public init(isSearchPresented: Bool = false,
                numberPadState: NumberPadState,
                searchState: SearchState) {
        self.isSearchPresented = isSearchPresented
        self.numberPadState = numberPadState
        self.searchState = searchState
    }
    
}

public enum HomeAction: Equatable {
    case onAppear
    case didLoad([Hymn])
    case search(action: SearchAction)
    case number(action: NumberPadAction)
}

public struct HomeEnvironment {
    var loadHymns: (Vernacular) -> Effect<[Hymn], Never>
}

public extension HomeEnvironment {
    static let live = Self(loadHymns: { vernacular in
        Effect(value: HymnManager.loadJsonHymns(for: vernacular))
            .eraseToEffect()
    })
}

public let homeReducer: Reducer<HomeState, HomeAction, HomeEnvironment> = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(numberPadReducer.pullback(
    state: \HomeState.numberPadState,
    action: (/HomeAction.number(action:)),
             environment: { _ in NumberPadEnvironment()}),
    searchReducer.pullback(
        state: \HomeState.searchState,
        action: (/HomeAction.search(action:)),
                 environment: { _ in SearchEnvironment() }),
        Reducer { state, action, environment in
            switch action {
                case .onAppear:
                    return environment
                        .loadHymns(state.currentVernacular)
                        .map(HomeAction.didLoad)
                case .didLoad(let hymns):
                    state.hymns = hymns
                    return Effect(value: .number(action: .setHymns(hymns)))
                        .eraseToEffect()
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
