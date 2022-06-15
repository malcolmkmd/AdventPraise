//
//  SearchView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import CoreUI
import SwiftUI
import ComposableArchitecture

public struct SearchView: View {
    
    @FocusState private var isFocused: Bool
    let store: Store<SearchState, SearchAction>
    
    public init(store: Store<SearchState, SearchAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                NavigationBar(
                    title: viewStore.activeHymnal.title,
                    action: {})
                .padding(.bottom, 20)
                HStack(spacing: 4) {
                    Button(action: { viewStore.send(.dismiss) }) {
                        Image(.arrowLeft)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.bounce())
                    VStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(.search)
                                .foregroundColor(.gray)
                            TextField(
                                "",
                                text: viewStore.binding(
                                    get: \.query,
                                    send: SearchAction.searchQueryChanged))
                            .focused($isFocused)
                            .placeholder(when: viewStore.query.isEmpty, placeholder: {
                                Text(viewStore.placeHolderText)
                                    .foregroundColor(.gray)
                            })
                        }
                        .font(.body)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            Capsule()
                                .strokeBorder(Color.gray, lineWidth: 1)
                        )
                        .padding(.horizontal, 8)
                    }
                }.padding(.horizontal)
                List {
                    ForEach(viewStore.results) { hymn in
                        HStack(spacing: 10) {
                            Text("\(hymn.id)")
                            Text(hymn.title)
                        }
                    }
                }
                .listStyle(.plain)
                .padding(.vertical, 20)
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                isFocused = true
            }
        }
    }
}





