//
//  SFSymbol+Image.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

public extension SwiftUI.Image {
    init(_ safeSymbol: SFSymbol) {
        self.init(systemName: safeSymbol.rawValue)
    }
}
