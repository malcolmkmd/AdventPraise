//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import SwiftUI
import LanguagePickerFeature
import ComposableArchitecture

public struct HomeView: View {
    
    @FocusState private var isFocused: Bool
    
    let store: Store<HomeState, HomeAction>
    
    public init(store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                HomeAppBar(store)
                Spacer()
                NumberPadView(store)
            }
        }
    }
    
    
//    public var body: some View {
//        WithViewStore(store) { viewStore in
//            ZStack {
//                Color(uiColor: .systemBackground)
//                    .ignoresSafeArea()
//                VStack {
//                    Spacer()
//                    GoButton
//                }
//                .isHidden(viewStore.isSearchPresented, remove: true)
//                .edgesIgnoringSafeArea(.bottom)
//                ZStack {
//                    VStack {

//                    }.padding(.bottom, 36)
//
//                    VStack {
//                        ZStack {
//                            List {
//                                ForEach(viewStore.results) { hymn in
//                                    HStack(spacing: 6) {
//                                        Text(hymn.id)
//                                            .font(.customHeadline)
//                                        Text(hymn.title)
//                                            .font(.customBodyItalic)
//                                            .lineLimit(1)
//                                        Spacer()
//                                    }
//                                    .contentShape(Rectangle())
//                                    .padding(.vertical, 6)
//                                    .padding(.leading, 4)
//                                    .listRowSeparator(.hidden)
//                                }
//                            }
//                            .listStyle(.plain)
//                            .scrollIndicators(.hidden)
//                            .scrollDismissesKeyboard(.immediately)
//                            .padding(.top, 108)
//                            .isHidden(!viewStore.isSearchPresented, remove: true)
//                            .edgesIgnoringSafeArea(.bottom)
//                            .modifier(SwipeToDismissModifier { dismissSearch(viewStore) })
//
//                            SearchComponent
//                            NavigationBar(
//                                title: viewStore.activeHymnal.title,
//                                leadingAction: { viewStore.send(.setViewMode(.languagePicker)) },
//                                trailingAction: {})
//                            .isHidden(viewStore.isSearchPresented, remove: true)
//                            .transition(AnyTransition.asymmetric(
//                                insertion: .move(edge: .top),
//                                removal: .move(edge: .top)
//                            ))
//                        }

//                    }
//                }
//            }
//        }
//    }
    
}

#if DEBUG
struct NumberPad_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: HomeState(hymns: HymnalClient.loadJsonHymns(), activeHymnal: .english), reducer: homeReducer, environment: HomeEnvironment())).loadCustomFonts()
    }
}
#endif
