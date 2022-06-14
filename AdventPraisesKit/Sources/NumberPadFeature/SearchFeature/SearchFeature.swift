//
//  SearchFeature.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Shared
import ComposableArchitecture

public struct SearchState: Equatable {
    
    var activeHymnal: String = "Christ in song"
    var results: [Hymn] = []
    var allHymns: [Hymn] = []
    var query: String = ""
    let placeHolderText: String = "Search title, lyrics, number..."
    
    public init(allHymns: [Hymn]) {
        self.results = allHymns
        self.allHymns = allHymns
    }
    
}

public enum SearchAction: Equatable {
    case dismiss
    case clearSearchQuery
    case searchQueryChanged(String)
}

public struct SearchEnvironment {}

public let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment> { state, action, environment in
    switch action {
        case .dismiss:
            return .none
        case .clearSearchQuery:
            state.query = ""
            return Effect(value: .searchQueryChanged(""))
                .eraseToEffect()
        case .searchQueryChanged(let query):
            if query.isEmpty {
                state.results = state.allHymns
            } else {
                state.results = state.allHymns.filter {
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
