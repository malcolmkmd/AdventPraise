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
    
    @ViewBuilder
    public func isHidden(_ hidden: Bool,
                         remove: Bool = false) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder
    public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
