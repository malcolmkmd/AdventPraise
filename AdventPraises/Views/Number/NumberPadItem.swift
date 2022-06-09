//
//  NumberPadButton.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Foundation

enum NumberPadItem: Hashable {
    case empty
    case number(Int)
    case delete
    
    var symbol: SafeSymbol? {
        switch self {
            case .delete: return .deleteLeftFill
            default: return nil
        }
    }
}

extension NumberPadItem {
    static let standardLayout: [[NumberPadItem]] = [
        [.number(1), .number(2), .number(3)],
        [.number(4), .number(5), .number(6)],
        [.number(7), .number(8), .number(9)],
        [.empty, .number(0), .delete]
    ]
}
