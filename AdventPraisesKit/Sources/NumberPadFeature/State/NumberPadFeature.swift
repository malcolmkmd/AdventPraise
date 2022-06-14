//
//  File.swift
//  
//
//  Created by Malcolm on 6/13/22.
//

import Shared
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
    
    var hymns: [Hymn] = []
    var activeHymnal: String = "Christ in song"
    var displayedText: String = "Search for a hymn"
    
    var searchIsPresented: Bool = false
    
    var hymnTitles: [String: String] {
        hymns.reduce(into: [String: String]()) {
            $0[$1.id] = $1.title
        }
    }
    
    public init() {}
}

public enum NumberPadAction: Equatable {
    case setHymns([Hymn])
    case didTapSearchField
    case setSearch(isPresented: Bool)
    case didTap(NumberPadItem)
    case didLongPress(NumberPadItem)
}

public struct NumberPadEnvironment {
    public init() {}
}

public let numberPadReducer = Reducer<NumberPadState, NumberPadAction, NumberPadEnvironment> { state, action, _ in
    switch action {
        case .setHymns(let hymns):
            state.hymns = hymns
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
