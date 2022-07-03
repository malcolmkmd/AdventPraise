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
                        case .number:
                            VStack {
                                NavBar
                                    .zIndex(1)
                                    .transition(.topSlideIn)
                                    .isHidden(viewStore.viewMode != .number, remove: true)
                                Spacer()
                                NumberPadView(store)
                            }
                            .sheet(isPresented: viewStore.binding(get: \.showAppMenu, send: HomeAction.showAppMenu(isPresented:))) {
                                VStack {
                                    HStack {
                                        
                                    }
                                    Button(action: { viewStore.send(.showAppMenu(isPresented: false), animation: .default) }) {
                                        Text("Dismiss")
                                            .underline()
                                    }
                                }
                            }
                    }
                }
            }.sheet(isPresented: viewStore.binding(
                get: \.showLanguagePicker,
                send: HomeAction.showLanguagePicker(isPresented:))) {
                    VStack {
                        LanguagePickerBar
                        List {
                            ForEach(Hymnal.allCases) { hymnal in
                                Button(action: {
                                    viewStore.send(.setHymnal(hymnal), animation: .default)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(hymnal.subtitle)
                                                .font(.customHeadline)
                                            Text(hymnal.title)
                                                .font(.customBody)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.customTitle3)
                                            .foregroundColor(.green)
                                            .isHidden(hymnal != viewStore.activeHymnal)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .padding(.vertical)
                        .presentationDetents([.medium, .large])
                    }
                }
        }
    }
    
    var NavBar: some View {
        WithViewStore(store) { viewStore in
            NavigationBar(
                title: viewStore.activeHymnal.title,
                leadingAction: { viewStore.send(.showLanguagePicker(isPresented: true), animation: .default) },
                trailingAction: {
                    viewStore.send(.showAppMenu(isPresented: true))
                })
        }
    }
    
    var LanguagePickerBar: some View {
        HStack {
            Text("Languages")
                .lineLimit(1)
                .foregroundColor(.accentColor)
                .font(.customTitle3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
}

