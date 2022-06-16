//
//  SearchFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Core
import ComposableArchitecture

public struct SearchState: Equatable {
    
    public var hymns: [Hymn] = []
    public var activeHymnal: Hymnal = .english
    
    var query: String = ""
    var results: [Hymn] = []
    let placeHolderText: String = "Search title, lyrics, number..."
    
    public init(hymns: [Hymn], activeHymnal: Hymnal) {
        self.results = hymns
        self.hymns = hymns
        self.activeHymnal = activeHymnal
    }
    
}

public enum SearchAction: Equatable {
    case dismiss
    case didTapHymnPicker
    case clearSearchQuery
    case searchQueryChanged(String)
}

public struct SearchEnvironment {
    public init() {}
}

public let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> { state, action, environment in
    switch action {
        case .dismiss:
            return .none
        case .didTapHymnPicker:
            return .none 
        case .clearSearchQuery:
            state.query = ""
            return Effect(value: .searchQueryChanged(""))
                .eraseToEffect()
        case .searchQueryChanged(let query):
            if query.isEmpty {
                state.results = state.hymns
            } else {
                state.results = state.hymns.filter {
                    $0.title.smartContains(query) || $0.lyrics.smartContains(query)
                }
            }
            state.query = query
            return .none
    }
}

extension String {
    func smartContains(_ other: String) -> Bool {
        let array: [String] = other
            .lowercased()
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        return array
            .reduce(true) { !$0
                ? false
                : (self.lowercased().range(of: $1) != nil )
            }
    }
}
