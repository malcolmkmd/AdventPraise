//
//  File.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import ComposableArchitecture

public struct HymnState: Equatable {
    
    public var showBottomBar: Bool = false
    public var activeHymn: Hymn = Hymn(title: "", subtitle: "", lyrics: "")
    public var hymns: [Hymn] = []
    
    public init(hymns: [Hymn]) {
        self.hymns = hymns
    }
    
}

public enum HymnAction: Equatable {
    case dismiss
    case didPressBack
    case nextHymn
    case previousHymn
    case onAppear
    case showBottomBar
}

public struct HymnEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    
    public init(mainQueue: AnySchedulerOf<DispatchQueue> = .main) {
        self.mainQueue = mainQueue
    }
}

public let hymnReducer = Reducer<HymnState, HymnAction, HymnEnvironment> { state, action, environment in
    switch action {
        case .onAppear:
            return Effect(value: .showBottomBar)
                .delay(for: 0.4, scheduler: environment.mainQueue.animation(.spring(response: 0.3, dampingFraction: 1)))
                .eraseToEffect()
        case .showBottomBar:
            state.showBottomBar = true
            return .none
        case .didPressBack:
            state.showBottomBar = false
            return Effect(value: .dismiss)
                .delay(for: 0.3, scheduler: environment.mainQueue.animation(.linear))
                .eraseToEffect()
        case .nextHymn:
            guard
                var id = Int(state.activeHymn.id),
                case let index = id - 1
            else { return .none }
            if index == state.hymns.count - 1 {
                state.activeHymn = state.hymns[0]
            } else {
                state.activeHymn = state.hymns[index + 1]
            }
            return .none
        case .previousHymn:
            guard
                var id = Int(state.activeHymn.id),
                case let index = id - 1
            else { return .none }
            if index == 0 {
                state.activeHymn = state.hymns[state.hymns.count - 1]
            } else {
                state.activeHymn = state.hymns[index - 1]
            }
            return .none
        case .dismiss:
            return .none
    }
}