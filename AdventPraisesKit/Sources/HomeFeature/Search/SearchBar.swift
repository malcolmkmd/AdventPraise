//
//  SearchBar.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct SearchBar: View {
    
    @FocusState private var isSearchFocused: Bool
    
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack {
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
                            .focused($isSearchFocused)
                            .disableAutocorrection(true)
                            .placeholder(when: viewStore.query.isEmpty, placeholder: {
                                Text(viewStore.placeHolderText)
                                    .font(.customBody)
                                    .foregroundColor(Color(uiColor: .systemBackground))
                            })
                        }
                        .foregroundColor(Color(uiColor: .white))
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                            isSearchFocused = true
                        })
                    }
                    .onDisappear {
                        viewStore.send(.searchQueryChanged(""))
                        isSearchFocused = false
                    }
                }
            }
            
        }
    }
}

