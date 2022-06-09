//
//  SafeSymbol.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Foundation

public enum SafeSymbol: String {
    case ellipsis
    case bookClosed
    case deleteLeftFill
    case squareGrid2x2
    case bookClosedFill
    case squareGrid2x2Fill
    
    public var rawValue: String {
        switch self {
            case .ellipsis: return "ellipsis"
            case .bookClosed: return "book.closed"
            case .squareGrid2x2: return "square.grid.2x2"
            case .deleteLeftFill: return "delete.left.fill"
            case .bookClosedFill: return "book.closed.fill"
            case .squareGrid2x2Fill: return "square.grid.2x2.fill"
        }
    }
}
