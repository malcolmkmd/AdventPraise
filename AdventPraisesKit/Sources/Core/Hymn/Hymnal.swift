//
//  Languages.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public enum Hymnal: String, CaseIterable, Identifiable, Equatable {
    
    case english = "english"
    case zulu = "zulu"
    case xhosa = "xhosa"
    
    public var id: String {
        title
    }
    
    public var title: String {
        switch self {
            case .english: return "Christ In Song"
            case .zulu: return "UKrestu Esihlabelelweni"
            case .xhosa: return "UKrestu Esihlabelelwen"
        }
    }
    
    public var subtitle: String {
        switch self {
            case .english: return "Engilish"
            case .zulu: return "IsiZulu/Ndebele"
            case .xhosa: return "IsiXhosa"
        }
    }
    
}
