//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import SwiftUI
import HymnalPickerFeature
import ComposableArchitecture

public struct HomeView: View {
    
    var namespace: Namespace.ID
    @FocusState private var isFocused: Bool
    
    let store: Store<HomeState, HomeAction>
    
    public init(store: Store<HomeState, HomeAction>,
                namespace: Namespace.ID) {
        self.store = store
        self.namespace = namespace
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    GoButton
                }
                .isHidden(viewStore.isSearchPresented, remove: true)
                .edgesIgnoringSafeArea(.bottom)
                ZStack {
                    VStack {
                        Color(UIColor.systemBackground)
                            .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: viewStore.showBottomCornerRadius ? 10: 0))
                            .shadow(
                                color: viewStore.showBottomCornerRadius ? Color.secondary : Color.clear,
                                radius: viewStore.showBottomCornerRadius ? 3: 0)
                            .mask(Rectangle().padding(.bottom, -10))
                    }.padding(.bottom, 36)
                    
                    VStack {
                        ZStack {
                            List {
                                ForEach(viewStore.results) { hymn in
                                    HStack(spacing: 6) {
                                        Text(hymn.id)
                                            .font(.customHeadline)
                                        Text(hymn.title)
                                            .font(.customBodyItalic)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 6)
                                    .padding(.leading, 4)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.plain)
                            .scrollIndicators(.hidden)
                            .scrollDismissesKeyboard(.immediately)
                            .padding(.top, 108)
                            .isHidden(!viewStore.isSearchPresented, remove: true)
                            .edgesIgnoringSafeArea(.bottom)
                            .modifier(SwipeToDismissModifier { dismissSearch(viewStore) })
                            
                            SearchComponent
                            NavigationBar(
                                title: viewStore.activeHymnal.title,
                                leadingAction: { viewStore.send(.didTapHymnPicker) },
                                trailingAction: {})
                            .isHidden(viewStore.isSearchPresented, remove: true)
                            .transition(AnyTransition.asymmetric(
                                insertion: .move(edge: .top),
                                removal: .move(edge: .top)
                            ))
                        }
                        VStack {
                            Spacer()
                            SearchButton(
                                action: { withAnimation(.spring(response: 0.3, dampingFraction: 1.3)) {
                                    viewStore.send(.setSearchPresented(isPresented: true))
                                    isFocused = true
                                }},
                                isActive: viewStore.showGoButton,
                                displayedText: viewStore.displayedText)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 60)
                            NumberPad
                        }
                        .isHidden(viewStore.isSearchPresented, remove: true)
                        .padding(.bottom, 36)
                    }
                }
            }
        }
    }
    
    var NumberPad: some View {
        WithViewStore(store) { viewStore in
            VStack {
                ForEach(NumberPadGrid.standard, id: \.self) { row in
                    HStack(spacing: 60) {
                        ForEach(row, id: \.self) { item in
                            NumberPadButton(item: item)
                                .frame(width: buttonWidth(), height: 60)
                                .simultaneousGesture(LongPressGesture()
                                    .onEnded { _ in
                                        viewStore.send(.didLongPress(.delete))
                                    }).highPriorityGesture(TapGesture()
                                        .onEnded { _ in
                                            if viewStore.activeNumber.count <= 1 {
                                                viewStore.send(.didTap(item), animation: .spring())
                                            } else {
                                                viewStore.send(.didTap(item))
                                            }
                                            
                                        })
                        }
                    }
                }
            }
        }
    }
    
    var SearchComponent: some View {
        WithViewStore(store) { viewStore in
            VStack {
                ZStack {
                    Color(UIColor.tintColor)
                        .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                        .shadow(radius: 3)
                        .mask(Rectangle().padding(.bottom, -10))
                        .ignoresSafeArea()
                    HStack {
                        HStack(spacing: 4) {
                            Image(.search)
                            TextField(
                                "",
                                text: viewStore.binding(
                                    get: \.query,
                                    send: HomeAction.searchQueryChanged))
                            .font(.customBody)
                            .foregroundColor(Color(uiColor: .black))
                            .focused($isFocused)
                            .disableAutocorrection(true)
                            .placeholder(when: viewStore.query.isEmpty, placeholder: {
                                Text(viewStore.placeHolderText)
                                    .font(.customBody)
                                    .foregroundColor(Color(uiColor: .systemBackground))
                            })
                        }
                        .font(.customBody)
                        .foregroundColor(Color(uiColor: .systemBackground))
                        CloseButton(action: {
                            dismissSearch(viewStore)
                        })
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
                Spacer()
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top),
                removal: .move(edge: .top)
            ))
            .isHidden(!viewStore.isSearchPresented, remove: true)
        }
    }
    
    var GoButton: some View {
        WithViewStore(store) { viewStore in
            Button(action: {}) {
                HStack {
                    Spacer()
                    Text("GO")
                        .font(.customTitle)
                        .foregroundColor(Color(UIColor.systemBackground))
                    Spacer()
                }.padding(.top, 16)
            }
            .background(Color(uiColor: .tintColor))
            .ignoresSafeArea()
            .frame(height: 110)
            .isHidden(!viewStore.showGoButton)
            .transition(AnyTransition.asymmetric(
                insertion: .move(edge: .bottom),
                removal: .move(edge: .bottom)
                    .combined(with: .opacity)
            ))
        }
    }
    
    private func dismissSearch(_ store: ViewStore<HomeState, HomeAction>) {
        isFocused = false
        store.send(.setSearchPresented(isPresented: false))
    }
    
    private func buttonWidth() -> CGFloat {
        (UIScreen.main.bounds.width - (5*12)) / 4
    }
}

#if DEBUG
struct NumberPad_Previews: PreviewProvider {
    @Namespace static var namespace
    static var previews: some View {
        HomeView(store: .init(initialState: HomeState(hymns: HymnalClient.loadJsonHymns(), activeHymnal: .english), reducer: homeReducer, environment: HomeEnvironment()), namespace: namespace).loadCustomFonts()
    }
}
#endif
