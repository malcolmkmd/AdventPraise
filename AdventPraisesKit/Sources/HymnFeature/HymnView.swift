//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public enum HymnLineSpacing: CaseIterable {
    case small, medium, large
    
    public var size: CGFloat {
        switch self {
            case .small: return 4
            case .medium: return 8
            case .large: return 12
        }
    }
}

extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

public struct HymnView: View {
    
    let store: Store<HymnState, HymnAction>
    @State private var horizontalOffset: CGFloat = 0.0
    @State private var verticalOffset: CGFloat = 0.0
    @State private var nextButtonScale : CGFloat = 1.0
    @State var isFavorite: Bool = false
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack(spacing: 0) {
                    HymnScrollView(store)
                        .transition(.opacity)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, viewStore.showBottomBarPadding ? 70 : 0)
                }
                .edgesIgnoringSafeArea(.horizontal)
                .zIndex(2)
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        icon(.arrowLeft, action: {
                            viewStore.send(.didPressBack, animation: .default)
                        })
                        Spacer()
                        icon(isFavorite ? .heartFill : .heart, action: {
                            isFavorite.toggle()
                        })
                        .foregroundStyle(isFavorite ? .red : .secondary)
                        icon(.playlistAdd, action: {})
                        icon(.settings,action: { viewStore.send(.showMenu(isPresented: true)) })
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal)
                    .frame(height: 78)
                    .background(Color(uiColor: .systemMint))
                }
                .isHidden(!viewStore.showBottomBar, remove: true)
                .transition(AnyTransition.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom)
                        .combined(with: .opacity)
                ))
                .zIndex(1)
            }
            .sheet(isPresented: viewStore.binding(
                get: \.showMenu,
                send: HymnAction.showMenu(isPresented:))) {
                    menu
                        .presentationDetents([.fraction(0.5)])
                }
                .edgesIgnoringSafeArea(.horizontal)
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    viewStore.send(.onAppear, animation: .default)
                }
                .transition(.opacity)
        }
    }
    
    var menu: some View {
        WithViewStore(store) { viewStore in
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.secondary)
                        .frame(width: 30, height: 3)
                        .padding(.bottom, 10)
                    HStack {
                        HStack {
                            Button(action: {}) {
                                Text("A")
                                    .foregroundColor(.label)
                                    .font(.customBody)
                                    .frame(width: geometry.size.width * 0.35, height: 50)
                                    .background(
                                        Color(uiColor: .systemFill)
                                            .clipShape(CustomCorners(
                                                corners: [.topLeft, .bottomLeft],
                                                radius: 10))
                                    )
                            }
                            Button(action: {}) {
                                Text("A")
                                    .foregroundColor(.label)
                                    .font(.customTitle)
                                    .frame(width: geometry.size.width * 0.35, height: 50)
                                    .background(
                                        Color(uiColor: .systemFill)
                                            .clipShape(CustomCorners(
                                                corners: [.topRight, .bottomRight],
                                                radius: 10))
                                    )
                            }
                        }
                        .frame(width: geometry.size.width * 0.75)
                        Spacer()
                        Button(action: { viewStore.send(.toggleLineSpacing, animation: .default)}) {
                            VStack(spacing: viewStore.lineSpacing.size) {
                                lineDivider()
                                lineDivider()
                                lineDivider()
                            }
                            .padding()
                            .foregroundColor(.secondary)
                            .frame(width: geometry.size.width * 0.20, height: 50)
                            .background(
                                Color(uiColor: .systemFill)
                                    .clipShape(CustomCorners(
                                        corners: .allCorners,
                                        radius: 10))
                            )
                        }
                    }
                    Button(action: {}) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Font")
                                    .font(.customCaption)
                                    .foregroundColor(.secondary)
                                Text("San Francisco")
                                    .foregroundColor(.label)
                            }
                            .padding()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .padding()
                        }.overlay(
                            RoundedRectangle(
                                cornerRadius: 10, style: .continuous)
                            .stroke(.secondary, lineWidth: 1)
                        )
                    }.buttonStyle(.plain)
                    Spacer()
                }
            }.padding()
        }
    }
    
    func lineDivider() -> some View {
        Color(uiColor: .label).frame(height:CGFloat(6) / UIScreen.main.scale)
    }
    
    func icon(_ icon: SFSymbol, action: @escaping () -> ()) -> some View {
        Button(action: action) {
            Image(icon)
                .font(.customTitle3)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.bounce(scale: 1.2))
        .frame(maxHeight: 60)
    }
    
    private func getOffset(rect: CGRect) -> CGFloat {
        if rect.origin.x >= 90 {
            return 0
        }
        return rect.origin.x
    }
}
