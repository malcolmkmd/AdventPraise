//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct GoButton: View {
    
    @Binding var isPresented: Bool
    var onTapped: () -> ()
    
    public init(isPresented: Binding<Bool>,
                onTapped: @escaping () -> ()) {
        self._isPresented = isPresented
        self.onTapped = onTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {}
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Color(UIColor.systemBackground)
                    .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10)))
                .mask(Rectangle())
            Button(action: { onTapped() }) {
                HStack {
                    Spacer()
                    Text("GO")
                        .offset(y: -8)
                        .font(.customTitle)
                        .foregroundColor(Color(UIColor.systemBackground))
                    Spacer()
                }
                .background(Color(uiColor: UIColor.tintColor))
                .padding(.vertical)
            }
        }
        .frame(maxHeight: 90)
        .background(Color(uiColor: UIColor.tintColor))
        .ignoresSafeArea()
        .isHidden(!isPresented)
        .transition(AnyTransition.asymmetric(
            insertion: .move(edge: .bottom),
            removal: .move(edge: .bottom)
        ))
    }
}
