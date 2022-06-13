//
//  File.swift
//  
//
//  Created by Malcolm on 6/13/22.
//

import SwiftUI
import ComposableArchitecture

public struct NumberPadState: Equatable {
    var isSearch: Bool = true {
        didSet {
            if isSearch {
                displayedText = "Search for a hymn"
            }
        }
    }
    
    var activeNumber: Int = 0 {
        didSet {
            guard let title = hymnTitles[activeNumber] else { return }
            displayedText = "\(activeNumber) \(title)"
            activeNumberString = "\(activeNumber)"
        }
    }
    
    var activeHymnal: String = "Christ in song"
    var activeNumberString: String = ""
    var displayedText: String = "Search for a hymn"
    lazy var hymnTitles: [Int: String] = {
        var dictionary: [Int:String] = [:]
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        for i in 0..<300 {
            dictionary[i] = "Hymn number \(formatter.string(for: NSNumber(integerLiteral: i))!.capitalized)"
        }
        return dictionary
    }()
    
    public init() {}
}

public enum NumberPadAction {
    case didTapSearchField
    case didTap(NumberPadItem)
    case didLongPress(NumberPadItem)
}

public struct NumberPadEnvironment {
    public init() {}
}

public let numberPadReducer = Reducer<NumberPadState, NumberPadAction, NumberPadEnvironment> { state, action, _ in
    switch action {
        case .didTapSearchField:
            
            return .none
        case .didTap(let item):
            switch item {
                case .delete:
                    guard !state.isSearch else { return .none }
                    state.activeNumberString = String(state.activeNumberString.dropLast())
                    if state.activeNumberString.isEmpty {
                        withAnimation {
                            state.isSearch = true
                        }
                    }
                    guard let activeNumber = Int(state.activeNumberString) else { return .none }
                    state.activeNumber = activeNumber
                    return .none
                case .number(let value):
                    if state.isSearch {
                        guard value != 0 else { return .none }
                        state.isSearch = false
                        state.activeNumber = value
                    } else {
                        let newActiveNumber = state.activeNumberString + "\(value)"
                        guard
                            let newActiveValue = Int(newActiveNumber),
                            newActiveValue <= 300
                        else { return .none }
                        state.activeNumber = newActiveValue
                    }
                    return .none
                case .empty:
                    return .none
            }
        case .didLongPress(let item):
            if item == .delete {
                state.isSearch = true
            }
    }
    return .none
}
