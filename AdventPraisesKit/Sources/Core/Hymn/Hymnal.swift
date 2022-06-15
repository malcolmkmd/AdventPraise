//
//  Languages.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public enum Hymnal: String {
    case english = "english"
    case zulu = "zulu"
    
    public var title: String {
        switch self {
            case .english: return "Christ In Song"
            case .zulu: return "UKrestu Esihlabelelweni"
        }
    }
    
    public var subtitle: String {
        switch self {
            case .english: return "Engilisu"
            case .zulu: return "IsiZulu/Ndebele"
        }
    }
    
}
