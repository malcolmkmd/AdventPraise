//
//  SafeSymbol+Image.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

public extension SwiftUI.Image {
    init(_ safeSymbol: SafeSymbol) {
        self.init(systemName: safeSymbol.rawValue)
    }
}
