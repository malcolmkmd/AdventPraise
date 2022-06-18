//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct NumberPadView: View {
    
    @FocusState private var isFocused: Bool
    
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack {
                    Spacer()
                    SearchButton(
                        action: {
                            if viewStore.state.activeNumber.isEmpty {
                                viewStore.send(.setViewMode(.search), animation: .default)
                                isFocused = true
                            }
                        },
                        isActive: viewStore.showGoButton,
                        displayedText: viewStore.displayedText)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 32)
                    NumberGrid(store)
                        .padding(.bottom, 54)
                }
                .zIndex(2)
                VStack {
                    Spacer()
                    GoButton(store)
                }
                .zIndex(1)
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .isHidden(viewStore.viewMode != .number, remove: true)
        }
    }
}

