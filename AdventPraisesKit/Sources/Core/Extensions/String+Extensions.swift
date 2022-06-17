//
//  File.swift
//  
//
//  Created by Malcolm on 6/17/22.
//

import Foundation

extension String {
    public func smartContains(_ other: String) -> Bool {
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
