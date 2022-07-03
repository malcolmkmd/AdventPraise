//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public enum HymnTextTheme: String, CaseIterable, Identifiable, Equatable {
    
    public var id: String {
        rawValue
    }
    
    case system, lightGrey, pale, darkGrey, navy
    
    var textColor: Color {
        switch self {
            case .system:
                    return .label
            case .lightGrey, .pale:
                return .black
            case .darkGrey, .navy:
                return .white
        }
    }
    
    var background: Color {
        switch self {
            case .system:
                    return .systemBackground
            case .lightGrey:
                return Color(red: 237 / 255, green: 239 / 255, blue: 239 / 255)
            case .pale:
                return Color(red: 252 / 255, green: 245 / 255, blue: 236 / 255)
            case .darkGrey:
                return Color(red: 44 / 255, green: 47 / 255, blue: 48 / 255)
            case .navy:
                return Color(red: 31 / 255, green: 41 / 255, blue: 57 / 255)
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
            case .system:
                return nil
            case .lightGrey, .pale:
                return .light
            case .darkGrey, .navy:
                return .dark
        }
    }
}

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
                        .frame(width: 60, height: 3)
                        .padding(.bottom, 10)
                    HStack {
                        HStack {
                            Button(action: { viewStore.send(.decreaseFont, animation: .default) }) {
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
                            Button(action: { viewStore.send(.increaseFont, animation: .default) }) {
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
                    ThemeSelector
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .padding()
        }
    }
    
    var ThemeSelector: some View {
        WithViewStore(store) { viewStore in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(HymnTextTheme.allCases) { theme in
                        VStack(spacing: 10) {
                            GeometryReader { geometry in
                                VStack(alignment: .leading) {
                                    theme.textColor
                                        .frame(height: 3)
                                        .frame(width: geometry.size.width)
                                    theme.textColor
                                        .frame(height: 3)
                                        .frame(width: geometry.size.width * 0.6)
                                    theme.textColor
                                        .frame(height: 3)
                                        .frame(width: geometry.size.width * 0.9)
                                    theme.textColor
                                        .frame(height: 3)
                                        .frame(width: geometry.size.width * 0.5)
                                }
                            }
                            .padding(.bottom, 8)
                            selector(for: theme)
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 4)
                        .frame(width: 70, height: 100)
                        .background(
                            theme.background.clipShape(RoundedRectangle(
                                cornerRadius: 10, style: .continuous))
                        ).onTapGesture {
                            viewStore.send(.setTheme(theme: theme), animation: .default)
                        }
                    }
                }
            }
        }
    }
    
    func selector(for theme: HymnTextTheme) -> some View {
        WithViewStore(store) { viewStore in
            if viewStore.theme.id == theme.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(theme.textColor)
            }
        }
    }
    
    func lineDivider() -> some View {
        Color(uiColor: .label)
            .frame(height:CGFloat(6) / UIScreen.main.scale)
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
