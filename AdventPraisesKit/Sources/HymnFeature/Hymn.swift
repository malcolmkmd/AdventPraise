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
    
    public init() {}
    
}

public enum HymnAction: Equatable {
    case dismiss
    case didPressBack
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
        case .dismiss:
            return .none
    }
}
