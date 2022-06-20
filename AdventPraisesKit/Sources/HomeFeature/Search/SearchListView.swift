//
//  SearchListView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct SearchListView: View {
    
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            List {
                ForEach(viewStore.results) { hymn in
                    HStack(spacing: 10) {
                        Text(hymn.id)
                            .font(.customSubheadline)
                        Text(hymn.title)
                            .font(.customBodyItalic)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewStore.send(.presentHymn(hymn), animation: .default)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .isHidden(viewStore.viewMode != .search, remove: true)
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}
