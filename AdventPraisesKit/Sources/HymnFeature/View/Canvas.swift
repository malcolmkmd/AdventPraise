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
    let store: Store<HymnState, HymnAction>
    
    init(_ store: Store<HymnState, HymnAction>, @ViewBuilder _ content: () -> Content) {
        self.store = store
        self.content = content()
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            content
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                .background(
                    viewStore.theme.background
                        .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                        .shadow(
                            color: viewStore.theme.background,
                            radius: 3)
                        .mask(Rectangle().padding(.bottom, -10))
                        .ignoresSafeArea()
                )
               
        }
    }
}
