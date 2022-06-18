//
//  Hymnal.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import Core
import ComposableArchitecture

public struct LanguagePickerState: Equatable {
    
    public var activeHymnal: Hymnal
    
    public init(activeHymnal: Hymnal) {
        self.activeHymnal = activeHymnal
    }
}

public enum LanguagePickerAction: Equatable {
    case dismiss
}

public struct LanguagePickerEnvironment {
    public init() {}
}

public let LanguagePickerReducer = Reducer<LanguagePickerState, LanguagePickerAction, LanguagePickerEnvironment> { state, action, environment in
    switch action {
        case .dismiss:
            return .none
    }
}
