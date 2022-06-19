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
    @State private var horizontalOffset: CGFloat = 0.0
    @State private var verticalOffset: CGFloat = 0.0
    @State private var nextButtonScale : CGFloat = 1.0
    
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
                        HymnScrollView(store)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity)
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
            .onAppear {
                viewStore.send(.onAppear, animation: .default)
            }
            .transition(.opacity)
        }
    }
    
    private func getOffset(rect: CGRect) -> CGFloat {
        if rect.origin.x >= 90 {
            return 0
        }
        return rect.origin.x
    }
}

private struct OffsetPreferenceKey: PreferenceKey {
    
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { }
    
}

struct OffsettableScrollView<T: View>: View {
    let axes: Axis.Set
    let onOffsetChanged: (CGPoint) -> Void
    let content: T
    
    init(axes: Axis.Set = .horizontal,
         onOffsetChanged: @escaping (CGPoint) -> Void = { _ in },
         @ViewBuilder content: () -> T) {
        self.axes = axes
        self.onOffsetChanged = onOffsetChanged
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: false) {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OffsetPreferenceKey.self,
                    value: proxy.frame(
                        in: .named("ScrollViewOrigin")
                    ).origin
                )
            }
            .frame(width: 0, height: 0)
            content
        }
        .coordinateSpace(name: "ScrollViewOrigin")
        .onPreferenceChange(OffsetPreferenceKey.self,
                            perform: onOffsetChanged)
    }
}
