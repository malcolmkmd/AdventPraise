//
//  BounceButtonStyle.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import SwiftUI

public struct BounceButtonStyle: ButtonStyle {
    
    let scale: CGFloat
    
    init(scale: CGFloat = 0.97) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        return configuration
            .label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeIn, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == BounceButtonStyle {
    static func bounce(scale: CGFloat = 0.97) -> BounceButtonStyle {
        return BounceButtonStyle(scale: scale)
    }
}
