//
//  DefaultKey.swift
//  
//
//  Created by Malcolm on 6/26/22.
//

import Foundation

public struct DefaultKey: RawRepresentable {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
}

extension DefaultKey: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        rawValue = stringLiteral
    }
}

extension DefaultKey {
    public static let selectedHymnal: DefaultKey = "selected_hymnal"
}
