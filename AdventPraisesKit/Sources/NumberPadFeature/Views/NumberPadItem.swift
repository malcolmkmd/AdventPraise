//
//  NumberPadButton.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import CoreUI

public enum NumberPadItem: Hashable {
    case empty
    case number(Int)
    case delete
    
    var symbol: SFSymbol? {
        switch self {
            case .delete: return .deleteLeftFill
            default: return nil
        }
    }
}

typealias NumberPadGrid = [[NumberPadItem]]
extension NumberPadGrid {
    static let standard: NumberPadGrid = [
        [.number(1), .number(2), .number(3)],
        [.number(4), .number(5), .number(6)],
        [.number(7), .number(8), .number(9)],
        [.empty, .number(0), .delete]
    ]
    
    static let inverted: NumberPadGrid = [
        [.number(1), .number(4), .number(7), .empty],
        [.number(2), .number(5), .number(8), .number(0)],
        [.number(3), .number(6), .number(9), .delete]
    ]
}
