//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import SwiftUI
import ComposableArchitecture

struct GoButton: View {
    
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            Button(action: {}) {
                HStack {
                    Spacer()
                    Text("GO")
                        .font(.customTitle)
                        .foregroundColor(Color(UIColor.systemBackground))
                    Spacer()
                }.padding(.vertical)
            }
            .frame(height: 60)
            .background(Color(uiColor: UIColor.tintColor))
            .ignoresSafeArea()
            .isHidden(!viewStore.showGoButton)
            .isHidden(viewStore.viewMode != .number, remove: true)
            .transition(AnyTransition.asymmetric(
                insertion: .move(edge: .bottom),
                removal: .move(edge: .bottom)
                    .combined(with: .opacity)
            ))        }
    }
}
