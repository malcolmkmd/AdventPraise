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
        rawValue
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
    
    public var hymns: [Hymn] {
        guard let path = Bundle.core.path(
            forResource: self.rawValue,
            ofType: "json")
        else { return [] }
        do {
            let json = try Data(
                contentsOf: URL(fileURLWithPath: path),
                options: .alwaysMapped)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromPascalCase
            let hymns = try decoder.decode([Hymn].self, from: json)
            return hymns
        } catch let error {
            print(error)
        }
        return []
    }

}
