//
//  Languages.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public enum Vernacular: String {
    case english = "english"
    
    var title: String {
        switch self {
            case .english: return "Christ In Song"
        }
    }
}
