//
//  SFSymbol.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Foundation

public enum SFSymbol: String {
    case close
    case search
    case ellipsis
    case arrowLeft
    case bookClosed
    case squareGrid2x2
    case gearshapeFill
    case bookClosedFill
    case deleteLeftFill
    case squareGrid2x2Fill
    case menu
    case placeHolderTextFill
    
    public var rawValue: String {
        switch self {
            case .close: return "xmark"
            case .ellipsis: return "ellipsis"
            case .arrowLeft: return "arrow.left"
            case .bookClosed: return "book.closed"
            case .search: return "text.magnifyingglass"
            case .gearshapeFill: return "gearshape.fill"
            case .squareGrid2x2: return "square.grid.2x2"
            case .menu: return "line.3.horizontal.decrease"
            case .deleteLeftFill: return "delete.left.fill"
            case .bookClosedFill: return "book.closed.fill"
            case .squareGrid2x2Fill: return "square.grid.2x2.fill"
            case .placeHolderTextFill: return "placeholdertext.fill"
        }
    }
}
