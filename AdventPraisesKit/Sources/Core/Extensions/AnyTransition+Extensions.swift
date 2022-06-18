//
//  File.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import SwiftUI

extension AnyTransition {
    
    /// Provides a composite transition that uses a different transition for
    /// insertion versus removal.
    public static var topSlideIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top),
            removal: .move(edge: .top)
                .combined(with: .opacity))
    }
}
