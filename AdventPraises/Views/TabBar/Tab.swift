//
//  Tab.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Foundation

enum Tab: String, CaseIterable {
    case number
    case hymns
    case more
    
    var title: String {
        switch self {
            case .more: return "More"
            case .hymns: return "Hymns"
            case .number: return "Number"
        }
    }
    
    var symbol: (standard: SafeSymbol, filled: SafeSymbol) {
        switch self {
            case .more: return (.ellipsis, .ellipsis)
            case .hymns: return (.bookClosed, .bookClosedFill)
            case .number: return (.squareGrid2x2, .squareGrid2x2Fill)
        }
    }
}
