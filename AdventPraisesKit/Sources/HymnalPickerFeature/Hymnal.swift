//
//  Hymnal.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import Core
import ComposableArchitecture

public struct HymnalPickerState: Equatable {
    
    public var activeHymnal: Hymnal
    
    public init(activeHymnal: Hymnal) {
        self.activeHymnal = activeHymnal
    }
}

public enum HymnalPickerAction: Equatable {
    case dismiss
}

public struct HymnalPickerEnvironment {
    public init() {}
}

public let hymnalPickerReducer = Reducer<HymnalPickerState, HymnalPickerAction, HymnalPickerEnvironment> { state, action, environment in
    switch action {
        case .dismiss:
            return .none
    }
}
