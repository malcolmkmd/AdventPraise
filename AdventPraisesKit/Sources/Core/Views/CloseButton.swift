//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/17/22.
//

import SwiftUI

public struct CloseButton: View {
    
    let action: () -> ()
    
    public init(action: @escaping () -> ()) {
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                action() }
        }) {
            Image(.close)
                .font(.customSubheadline)
                .foregroundColor(.secondary)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.bounce())
    }
}