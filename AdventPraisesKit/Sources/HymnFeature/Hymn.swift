//
//  File.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import ComposableArchitecture

public struct HymnState: Equatable {
    
    public struct ScrollViewState: Equatable {
        var activeViewIndex: Int = 1
        var screenDrag: Float = 0.0
        var shouldPlayLeftImpact: Bool = true
        var shouldPlayRightImpact: Bool = true
    }
    
    public var hymns: [Hymn] {
        activeHymnal.hymns
    }
    
    var scrollViewState: ScrollViewState = ScrollViewState()
    public var activeHymn: Hymn
    public var activeHymnal: Hymnal
    public var showMenu: Bool = false
    public var isFavorite: Bool = true
    public var showBottomBar: Bool = false
    public var showBottomBarPadding: Bool = false
    public var lineSpacing: HymnLineSpacing = .small
    
    public init(activeHymnal: Hymnal, activeHymn: Hymn) {
        self.activeHymn = activeHymn
        self.activeHymnal = activeHymnal
    }
    
}

public enum HymnAction: Equatable {
    case dismiss
    case onAppear
    case nextHymn
    case previousHymn
    case didPressBack
    case showBottomBar
    case showBottomBarPadding
    case showMenu(isPresented: Bool)
    case toggleLineSpacing
    case setHymnScrollDrag(value: Float)
    case shouldPlayScrollImpact(left: Bool, right: Bool)
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
            return .merge(Effect(value: .showBottomBar)
                .delay(for: 0.4, scheduler: environment.mainQueue.animation(.spring(response: 0.3, dampingFraction: 1)))
                .eraseToEffect(), Effect(value: .showBottomBarPadding)
                .delay(for: 0.6, scheduler: environment.mainQueue.animation(.spring(response: 0.3, dampingFraction: 1)))
                .eraseToEffect())
        case .showBottomBar:
            state.showBottomBar = true
            return .none
        case .showBottomBarPadding:
            state.showBottomBarPadding = true
            return .none
        case .didPressBack:
            state.showBottomBar = false
            state.showBottomBarPadding = false
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
        case .toggleLineSpacing:
            state.lineSpacing = state.lineSpacing.next()
            return .none
        case .showMenu(let isPresented):
            state.showMenu = isPresented
            return .none 
        case .dismiss:
            return .none
        case .shouldPlayScrollImpact(let left, let right):
            state.scrollViewState.shouldPlayLeftImpact = left
            state.scrollViewState.shouldPlayRightImpact = right
            return .none
        case .setHymnScrollDrag(let value):
            state.scrollViewState.screenDrag = value
            return .none 
    }
}
