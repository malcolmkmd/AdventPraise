//
//  HymnManager.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public struct HymnManager {
    
    public static func loadJsonHymns(for language: Vernacular = .english) -> [Hymn] {
        guard let path = Bundle.module.path(
            forResource: language.rawValue,
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
