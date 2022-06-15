//
//  SwipeToDismissModifier.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import SwiftUI

public struct SwipeToDismissModifier: ViewModifier {
    public var onDismiss: () -> Void
    @State private var offset: CGSize = .zero
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(y: offset.height)
            .animation(.interactiveSpring(), value: offset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width < 50 {
                            offset = gesture.translation
                        }
                    }
                    .onEnded { _ in
                        if abs(offset.height) > 100 {
                            onDismiss()
                        } else {
                            offset = .zero
                        }
                    }
            )
    }
}
