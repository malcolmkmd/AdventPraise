//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public struct HymnView: View {
    
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text(viewStore.activeHymn.id)
                                .font(.customTitle)
                            Text(viewStore.activeHymn.title)
                                .font(.customTitle2)
                            Text(viewStore.activeHymn.subtitle)
                                .font(.customBodyItalic)
                                .padding(.bottom, 16)
                        }.padding(.horizontal, 8)
                        Spacer()
                        ScrollView {
                            Text(viewStore.activeHymn.lyrics)
                                .padding(.bottom, 16)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(UIColor.systemBackground)
                            .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                            .shadow(
                                color: Color(uiColor: .systemBackground),
                                radius: 3)
                            .mask(Rectangle().padding(.bottom, -10))
                    )
                    .padding(.bottom, 70)
                }
                .edgesIgnoringSafeArea(.horizontal)
                .zIndex(2)
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { viewStore.send(.didPressBack, animation: .default) }) {
                            Image(.arrowLeft)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce())
                        Spacer()
                        Button(action: { }) {
                            Image(systemName: "heart")
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        Button(action: { }) {
                            Image(systemName: "plus")
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        Button(action: { }) {
                            Image(.gearshapeFill)
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal)
                    .frame(height: 78)
                    .background(Color(uiColor: .systemMint))
                }
                .isHidden(!viewStore.showBottomBar, remove: false)
                .transition(AnyTransition.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom)
                        .combined(with: .opacity)
                ))
                .zIndex(1)
            }
            .edgesIgnoringSafeArea(.horizontal)
            .edgesIgnoringSafeArea(.bottom)
            .onTapGesture {
                viewStore.send(.dismiss)
            }
            .onAppear {
                viewStore.send(.onAppear, animation: .default)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
    
}
