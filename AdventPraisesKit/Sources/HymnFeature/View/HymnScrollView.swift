//
//  HymnScrollView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/19/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct HymnScrollView: View {
    
    let spacing: CGFloat = 24
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            Canvas {
                Carousel(store, numberOfItems: CGFloat(3), spacing: spacing) {
                    IdentifiableView(id: 0) {
                        HStack {
                            Image(.arrowLeft)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .frame(widthAndHeight: 40)
                                .background(.regularMaterial, in: Circle())
                        }
                        .frame(widthAndHeight: 40)
                    }
                    IdentifiableView(id: 1) {
                        HymnText(viewStore.activeHymn.markdown)
                            .offset(y: 0)
                    }
                    IdentifiableView(id: 2) {
                        HStack {
                            Image(.arrowRight)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .frame(widthAndHeight: 40)
                                .background(.regularMaterial, in: Circle())
                        }
                    }
                }
            }
        }
    }
}




