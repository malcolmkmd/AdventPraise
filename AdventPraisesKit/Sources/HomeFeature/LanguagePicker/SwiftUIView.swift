//
//  LanguagePickerBar.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct LanguagePickerBar: View {
    
    let store: Store<HomeState, HomeAction>
    
    public init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
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
                Spacer()
            }
            .isHidden(viewStore.viewMode != .languagePicker, remove: true)
        }
    }
}
