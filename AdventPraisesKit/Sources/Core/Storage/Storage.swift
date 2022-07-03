//
//  File.swift
//  
//
//  Created by Malcolm on 6/26/22.
//

import Foundation

public struct Storage {

    @Default(.selectedHymnal, defaultValue: Hymnal.english.id)
    public var selectedHymnalId: String

    public func set<T>(key: DefaultKey, newValue: T) {
        UserDefaults.standard.set(newValue, forKey: key.rawValue)
    }
    
    public init() {}
}





