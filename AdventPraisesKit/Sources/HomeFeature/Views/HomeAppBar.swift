//
//  HomeAppBar.swift
//  AdventPraises
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct HomeAppBar: View {
    
    let store: Store<HomeState, HomeAction>
    
    @FocusState private var isSearchFocused: Bool
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                SearchBar
                    .zIndex(3)
                    .transition(.topSlideIn)
                    .isHidden(viewStore.viewMode != .search, remove: true)
                LanguagePickerBar
                    .zIndex(2)
                    .transition(.topSlideIn)
                    .isHidden(viewStore.viewMode != .languagePicker, remove: true)
                NavBar
                    .zIndex(1)
                    .transition(.topSlideIn)
                    .isHidden(viewStore.viewMode != .number, remove: true)
            }
        }
    }
    
    var NavBar: some View {
        WithViewStore(store) { viewStore in
            NavigationBar(
                title: "Christ In Song",
                leadingAction: { viewStore.send(.setViewMode(.languagePicker), animation: .default) },
                trailingAction: { })
        }
    }
    
    var SearchBar: some View {
        WithViewStore(store) { viewStore in
            AppBar(closeAction: { viewStore.send(.setViewMode(.number), animation: .default) }) {
                HStack(spacing: 4) {
                    Image(.search)
                    TextField(
                        "",
                        text: viewStore.binding(
                            get: \.query,
                            send: HomeAction.searchQueryChanged))
                    .lineLimit(1)
                    .font(.customBody)
                    .accentColor(Color(uiColor: .systemBackground))
                    .foregroundColor(Color(uiColor: .black))
                    .focused($isSearchFocused)
                    .disableAutocorrection(true)
                    .placeholder(when: viewStore.query.isEmpty, placeholder: {
                        Text(viewStore.placeHolderText)
                            .font(.customBody)
                            .foregroundColor(Color(uiColor: .systemBackground))
                    })
                }
            }
        }
    }
    
    var LanguagePickerBar: some View {
        WithViewStore(store) { viewStore in
            AppBar(
                color: Color(uiColor: .systemTeal),
                closeAction: { viewStore.send(.setViewMode(.number), animation: .default) }) {
                HStack {
                    Text("Languages")
                        .lineLimit(1)
                        .font(.customTitle3)
                    Spacer()
                }
            }
        }
    }
    
}

