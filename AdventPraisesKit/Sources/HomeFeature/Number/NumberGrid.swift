//
//  NumberGrid.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct NumberGrid: View {
    
    let store: Store<HomeState, HomeAction>
    
    init(_ store: Store<HomeState, HomeAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                ForEach(NumberPadGrid.standard, id: \.self) { row in
                    HStack(spacing: 60) {
                        ForEach(row, id: \.self) { item in
                            NumberPadButton(item: item)
                                .frame(width: buttonWidth(), height: 60)
                                .simultaneousGesture(LongPressGesture()
                                    .onEnded { _ in
                                        viewStore.send(.didLongPress(.delete))
                                    }).highPriorityGesture(TapGesture()
                                        .onEnded { _ in
                                            if viewStore.activeNumber.count <= 1 {
                                                viewStore.send(.didTap(item), animation: .spring())
                                            } else {
                                                viewStore.send(.didTap(item))
                                            }
                                            
                                        })
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .edgesIgnoringSafeArea(.horizontal)
        }
    }
    
    private func buttonWidth() -> CGFloat {
        (UIScreen.main.bounds.width - (5*12)) / 4
    }
    
}

