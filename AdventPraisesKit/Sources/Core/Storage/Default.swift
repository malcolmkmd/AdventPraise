//
//  File.swift
//  
//
//  Created by Malcolm on 6/26/22.
//

import Foundation

@propertyWrapper
public struct Default<T> {
    private let key: DefaultKey
    private let defaultValue: T
    
    public var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key.rawValue) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key.rawValue)
        }
    }
    
    public init(_ key: DefaultKey, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
}
