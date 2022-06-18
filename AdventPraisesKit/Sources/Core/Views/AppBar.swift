//
//  AppBar.swift
//  AdventPraises
//
//  Created by Malcolm on 6/18/22.
//

import SwiftUI

public struct AppBar<Content: View>: View {
    
    let color: Color
    let closeAction: () -> ()
    @ViewBuilder let content: () -> Content
    
    public init(color: Color = Color(uiColor: UIColor.tintColor),
                closeAction: @escaping () -> (),
                @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.content = content
        self.closeAction = closeAction
    }
    
    public var body: some View {
        HStack {
            HStack {
                content()
                    .frame(maxWidth: .infinity)
            }
            .foregroundColor(Color(uiColor: .systemBackground))
            CloseButton(action: { withAnimation { closeAction() }})
                .buttonStyle(.bounce())
        }
        .padding()
        .background(
            color
                .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                .shadow(radius: 3)
                .mask(Rectangle().padding(.bottom, -10))
                .ignoresSafeArea()
        )
    }
}

