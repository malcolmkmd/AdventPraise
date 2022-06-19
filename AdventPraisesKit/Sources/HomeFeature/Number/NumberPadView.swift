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
    
    let store: Store<HomeState, HomeAction>
    let goButtonHeight: CGFloat = 60
    
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
                                viewStore.send(
                                    .setViewMode(.search),
                                    animation: .default)
                            } else {
                                viewStore.send(.presentHymn(viewStore.activeHymn),
                                               animation: .default)
                            }
                        },
                        isActive: viewStore.showGoButton,
                        displayedText: viewStore.displayedText)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 40)
                    NumberGrid(store)
                        .padding(.bottom, goButtonHeight)
                }
                .zIndex(2)
                VStack {
                    Spacer()
                    GoButton(store, height: goButtonHeight)
                }
                .zIndex(1)
            }
            .ignoresSafeArea()
            .isHidden(viewStore.viewMode != .number, remove: true)
            .onAppear {
                viewStore.send(.didLongPress(.delete))
            }
        }
    }
}
