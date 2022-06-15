//
//  File.swift
//  
//
//  Created by Malcolm on 6/13/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public struct NumberPadState: Equatable {
    
    var hasActiveNumber: Bool {
        activeNumber.isEmpty
    }
    
    var activeNumber: String = "" {
        didSet {
            guard
                !activeNumber.isEmpty,
                let title = hymnTitles[activeNumber]
            else {
                displayedText = "Search for a hymn"
                return
            }
            displayedText = "\(activeNumber) \(title)"
        }
    }
    
    var hymnTitles: [String: String] {
        hymns.reduce(into: [String: String]()) {
            $0[$1.id] = $1.title
        }
    }
    
    public var hymns: [Hymn]
    public var activeHymnal: Hymnal
    
    var displayedText: String = "Search for a hymn"
    var searchIsPresented: Bool = false
    
    public init(hymns: [Hymn],
                activeHymnal: Hymnal) {
        self.hymns = hymns
        self.activeHymnal = activeHymnal
    }
}

public enum NumberPadAction: Equatable {
    case didTapSearchField
    case changeHymnal(Hymnal)
    case didTap(NumberPadItem)
    case didLongPress(NumberPadItem)
    case setSearch(isPresented: Bool)
}

public struct NumberPadEnvironment {
    public init() {}
}

public let numberPadReducer = Reducer<NumberPadState, NumberPadAction, NumberPadEnvironment> { state, action, _ in
    switch action {
        case .changeHymnal(let hymnal):
            return .none 
        case .didTapSearchField:
            if state.activeNumber.isEmpty {
                return Effect(value: .setSearch(isPresented: true))
                    .eraseToEffect()
            }
            return .none
        case .setSearch(let isPresented):
            state.searchIsPresented = isPresented
        case .didTap(let item):
            switch item {
                case .delete:
                    guard !state.activeNumber.isEmpty else { return .none }
                    state.activeNumber = String(state.activeNumber.dropLast())
                    return .none
                case .number(let value):
                    let newActiveNumber = state.activeNumber + "\(value)"
                    guard
                        let newActiveValue = Int(newActiveNumber),
                        newActiveValue <= state.hymns.count
                    else { return .none }
                    state.activeNumber = newActiveNumber
                    return .none
                case .empty:
                    return .none
            }
        case .didLongPress(let item):
            state.activeNumber = ""
            return .none
    }
    return .none
}
