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
                        icon(.settings, action: {})
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
            .edgesIgnoringSafeArea(.horizontal)
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                viewStore.send(.onAppear, animation: .default)
            }
            .transition(.opacity)
        }
    }
    
    func icon(_ icon: SFSymbol, action: @escaping () -> ()) -> some View {
        Button(action: action) {
            Image(icon)
                .font(.customTitle3)
//                .foregroundColor(.secondary)
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
