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
                                viewStore.send(
                                    .presentHymn(viewStore.activeHymn),
                                    animation: .default)
                            }
                        },
                        isActive: viewStore.showBottomBar,
                        displayedText: viewStore.displayedText)
                    .padding(.horizontal, 8)
                    NumberGrid(store)
                        .padding(.bottom, goButtonHeight)
                }
                .zIndex(2)
                VStack {
                    Spacer()
                    GoButton(
                        isPresented: viewStore.binding(
                            get: \.showBottomBar,
                            send: HomeAction.showBottomBar(isPresented:)),
                        onTapped: {
                            viewStore.send(.goButtonTapped, animation: .none)
                        })
                    .offset(y: 2)
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

