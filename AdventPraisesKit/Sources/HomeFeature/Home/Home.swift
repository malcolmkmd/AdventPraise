//
//  File.swift
//  
//
//  Created by Malcolm on 6/13/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public enum HomeViewMode {
    case number, search, languagePicker
}

public struct HomeState: Equatable {
    
    public var activeNumber: String = "" {
        didSet {
            guard
                !activeNumber.isEmpty,
                let title = hymnTitles[activeNumber]
            else {
                showGoButton = false
                showBottomCornerRadius = false
                displayedText = "Search for a hymn"
                return
            }
            displayedText = "\(activeNumber) \(title)"
            showGoButton = true
        }
    }
    
    public var activeTitle: String {
        hymnTitles[activeNumber] ?? ""
    }
    
    var hymnTitles: [String: String] {
        hymns.reduce(into: [String: String]()) {
            $0[$1.id] = $1.title
        }
    }
    
    public var hymns: [Hymn]
    public var activeHymn: Hymn {
        hymns[(Int(activeNumber) ?? 0) - 1]
    }
    public var activeHymnal: Hymnal = .english
    
    var viewMode: HomeViewMode = .number
    var query: String = ""
    var results: [Hymn]
    var showGoButton: Bool = false
    var showBottomCornerRadius: Bool = false
    var displayedText: String = "Search for a hymn"
    let placeHolderText: String = "Search title, lyrics, number"
    
    public init(hymns: [Hymn],
                activeHymnal: Hymnal) {
        self.hymns = hymns
        self.results = hymns
        self.activeHymnal = activeHymnal
    }
}

public enum HomeAction: Equatable {
    case didTap(NumberPadItem)
    case didLongPress(NumberPadItem)
    case setViewMode(HomeViewMode)
    case clearSearchQuery
    case goButtonShown
    case searchQueryChanged(String)
    case presentHymn(Hymn)
}

public struct HomeEnvironment {
    
    var mainQueue: AnySchedulerOf<DispatchQueue>
    
    public init(mainQueue: AnySchedulerOf<DispatchQueue> = .main) {
        self.mainQueue = mainQueue
    }
}

public let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment> { state, action, environment in
    switch action {
        case .setViewMode(let viewMode):
            state.viewMode = viewMode
            return .none
        case .didTap(let item):
            switch item {
                case .delete:
                    guard !state.activeNumber.isEmpty else { return .none }
                    state.activeNumber = String(state.activeNumber.dropLast())
                    return .none
                case .number(let value):
                    if state.activeNumber.isEmpty, value == 0 {
                        return .none
                    }
                    let newActiveNumber = state.activeNumber + "\(value)"
                    guard
                        let newActiveValue = Int(newActiveNumber),
                        newActiveValue <= state.hymns.count
                    else { return .none }
                    state.activeNumber = newActiveNumber
                    return Effect(value: HomeAction.goButtonShown)
                        .delay(for: 0.3, scheduler: environment.mainQueue)
                        .eraseToEffect()
                case .empty:
                    return .none
            }
        case .goButtonShown:
            state.showBottomCornerRadius = true
            return .none 
        case .didLongPress(let item):
            guard item == .delete else { return .none }
            state.activeNumber = ""
            return .none
        case .clearSearchQuery:
            state.query = ""
            return Effect(value: .searchQueryChanged(""))
                .eraseToEffect()
        case .searchQueryChanged(let query):
            withAnimation {
                if query.isEmpty {
                    state.results = state.hymns
                } else {
                    state.results = state.hymns.filter {
                        $0.title.smartContains(query) || $0.lyrics.smartContains(query)
                    }
                }
            }
            state.query = query
            return .none
        case .presentHymn:
            return .none
    }
}
