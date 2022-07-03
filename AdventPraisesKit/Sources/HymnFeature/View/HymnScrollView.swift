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
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading) {
                                    Text(viewStore.activeHymn.id)
                                        .font(.customTitle)
                                    Text(viewStore.activeHymn.title)
                                        .font(.customTitle3)
                                    Text(viewStore.activeHymn.subtitle)
                                        .font(.customBodyItalic)
                                }
                                .frame(
                                    minWidth: 0,
                                    maxWidth: .infinity,
                                    minHeight: 0,
                                    maxHeight: .infinity,
                                    alignment: .topLeading
                                )
                                .padding(.bottom, 8)
                                .padding(.horizontal, 16)
                                HymnText(viewStore.activeHymn.markdown).lineSpacing(viewStore.lineSpacing.size)
                                    .offset(y: 0)
                            }
                        }
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




