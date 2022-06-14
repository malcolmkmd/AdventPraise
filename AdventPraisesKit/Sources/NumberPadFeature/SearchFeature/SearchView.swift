//
//  SearchView.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Shared
import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    
    @FocusState private var isFocused: Bool
    let store: Store<SearchState, SearchAction>
    
    public init(store: Store<SearchState, SearchAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                NavigationBar(viewStore)
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
    
    @ViewBuilder
    private func NavigationBar(_ viewStore: ViewStore<SearchState, SearchAction>) -> some View {
        HStack {
            Button(action: {}) {
                HStack {
                    Image(.bookClosed)
                        .font(.title)
                    Text(viewStore.activeHymnal)
                        .lineLimit(1)
                        .font(.title)
                }
            }.buttonStyle(.bounce())
            Spacer()
            Button(action: {}) {
                Image(.gearshapeFill)
                    .font(.title)
            }.buttonStyle(.bounce(scale: 0.7))
        }.padding(.all, 16)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}

#if DEBUG
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(store: .init(
            initialState: SearchState(allHymns: Hymn.mockList),
            reducer: searchReducer,
            environment: SearchEnvironment()))
    }
}
#endif


