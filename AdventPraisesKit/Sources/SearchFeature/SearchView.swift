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
                HStack(spacing: 4) {
                    VStack {
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
                        .font(.bodyCustom)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            Capsule()
                                .strokeBorder(Color.gray, lineWidth: 1)
                        )
                        .padding(.horizontal, 8)
                    }
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewStore.send(.dismiss) }
                    }) {
                        Image(systemName: "xmark")
                            .font(.bodyCustom)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
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


#if DEBUG
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(store: .init(initialState: SearchState(hymns: [], activeHymnal: .english), reducer: searchReducer, environment: SearchEnvironment()))
            .loadCustomFonts()
    }
}
#endif
