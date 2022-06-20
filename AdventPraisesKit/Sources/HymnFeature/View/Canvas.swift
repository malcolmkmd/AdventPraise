//
//  Canvas.swift
//  
//
//  Created by Malcolm on 6/20/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct Canvas<Content : View> : View {
    let content: Content
    
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .background(
                Color(UIColor.systemBackground)
                    .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                    .shadow(
                        color: Color(uiColor: .systemBackground),
                        radius: 3)
                    .mask(Rectangle().padding(.bottom, -10))
            )
    }
}
