//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
        
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack {
                    switch viewStore.viewMode {
                        case .search:
                            SearchBar(store)
                                .zIndex(3)
                                .transition(.topSlideIn)
                            SearchListView(store)
                        case .languagePicker:
                            LanguagePickerBar
                                .zIndex(2)
                                .transition(.topSlideIn)
                                .isHidden(viewStore.viewMode != .languagePicker, remove: true)
                            List {
                                ForEach(Hymnal.allCases) { hymnal in
                                    Button(action: {
                                        viewStore.send(.setHymnal(hymnal), animation: .default)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(hymnal.subtitle)
                                                    .font(.customTitle3)
                                                Text(hymnal.title)
                                                    .font(.customBody)
                                            }
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.customTitle3)
                                                .isHidden(hymnal != viewStore.activeHymnal)
                                        }
                                    }
                                }
                            }
                            .listStyle(.inset)
                            .padding()
                            .isHidden(viewStore.viewMode != .languagePicker, remove: true)
                            .transition(.topSlideIn)
                        case .number:
                            VStack {
                                NavBar
                                    .zIndex(1)
                                    .transition(.topSlideIn)
                                    .isHidden(viewStore.viewMode != .number, remove: true)
                                Spacer()
                                NumberPadView(store)
                            }
                    }
                }
            }
        }
    }
    
    var NavBar: some View {
        WithViewStore(store) { viewStore in
            NavigationBar(
                title: viewStore.activeHymnal.title,
                leadingAction: { viewStore.send(.setViewMode(.languagePicker), animation: .default) },
                trailingAction: { })
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

