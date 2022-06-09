//
//  View+Extensions.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

extension View {
    @inlinable
    public func frame(widthAndHeight size: CGFloat? = nil) -> some View {
        self.frame(width: size, height: size)
    }
}
