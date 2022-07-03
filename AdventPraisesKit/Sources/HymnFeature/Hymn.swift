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
    public var theme: HymnTextTheme = .system
    public var fontName: String = CustomFonts.jetMedium.rawValue
    public var fontSize: CGFloat = 16
    
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
    case increaseFont
    case decreaseFont
    case setTheme(theme: HymnTextTheme)
    case showMenu(isPresented: Bool)
    case showBottomBarPadding(isPresented: Bool)
    case showBottomBar(isPresented: Bool)
    case didTapHymnView
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
            return .merge(Effect(value: .showBottomBar(isPresented: true))
                .delay(for: 0.4, scheduler: environment.mainQueue.animation(.spring(response: 0.3, dampingFraction: 1)))
                .eraseToEffect(), Effect(value: .showBottomBarPadding(isPresented: true))
                .delay(for: 0.6, scheduler: environment.mainQueue.animation(.spring(response: 0.3, dampingFraction: 1)))
                .eraseToEffect())
        case .showBottomBar(let isPresented):
            state.showBottomBar = isPresented
            return .none
        case .setTheme(let theme):
            state.theme = theme
            return .none
        case .showBottomBarPadding(let isPresented):
            state.showBottomBarPadding = isPresented
            return .none
        case .increaseFont:
            let newSize = state.fontSize + 4
            state.fontSize = newSize >= 40 ? 40 : newSize
            return .none
        case .decreaseFont:
            let newSize = state.fontSize - 4
            state.fontSize = newSize <= 12 ? 12 : newSize
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
        case .didTapHymnView:
            if state.showBottomBarPadding {
                state.showBottomBarPadding.toggle()
                return Effect(value: .showBottomBar(isPresented: state.showBottomBarPadding))
                    .delay(for: 0.3, scheduler: environment.mainQueue.animation(.linear))
                    .eraseToEffect()
            } else {
                state.showBottomBar.toggle()
                return Effect(value: .showBottomBarPadding(isPresented: state.showBottomBar))
                    .delay(for: 0.3, scheduler: environment.mainQueue.animation(.linear))
                    .eraseToEffect()
            }
            
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
