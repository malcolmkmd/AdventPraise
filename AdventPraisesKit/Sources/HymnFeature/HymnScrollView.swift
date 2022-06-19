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
    
    let spacing: CGFloat = 16
    let widthOfHiddenButtons: CGFloat = 24
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            Canvas {
                Carousel(store, numberOfItems: CGFloat(3), spacing: spacing) {
                    HymnScrollItem(id: 0) {
                        HStack {
                            Image(.arrowLeft)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .frame(widthAndHeight: 40)
                                .background(.regularMaterial, in: Circle())
                        }
                        .frame(widthAndHeight: 40)
                    }
                    HymnScrollItem(id: 1) {
                        HymnText(viewStore.activeHymn.markdown)
                    }
                    HymnScrollItem(id: 2) {
                        HStack {
                            Image(.arrowRight)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 40, minHeight: 40)
                                .background(.regularMaterial, in: Circle())
                        }
                        .frame(widthAndHeight: 40)
                    }
                }
            }
            .background(Color.clear)
        }
    }
}

struct Carousel<Items : View> : View {
    let items: Items
    let numberOfItems: CGFloat
    let spacing: CGFloat
    let totalSpacing: CGFloat
    let cardWidth: CGFloat
    
    @GestureState var isDetectingLongPress = false
    
    let store: Store<HymnState, HymnAction>
    
    public init(
        _ store: Store<HymnState, HymnAction>,
        numberOfItems: CGFloat,
        spacing: CGFloat,
        @ViewBuilder _ items: () -> Items) {
            self.store = store
            self.items = items()
            self.numberOfItems = numberOfItems
            self.spacing = spacing
            self.totalSpacing = (numberOfItems - 1) * spacing
            self.cardWidth = UIScreen.main.bounds.width - (32*2) - (spacing*2)
        }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            
            HStack(alignment: .center, spacing: spacing) {
                items
            }
            .background(Color(uiColor: .clear))
            .offset(x: CGFloat(getOffSet(viewStore)), y: 0)
            .gesture(DragGesture().updating($isDetectingLongPress) { currentState, gestureState, transaction in
                guard
                    currentState.translation.width <= 100,
                    currentState.translation.width >= -100
                else {
                    if viewStore.scrollViewState.shouldPlayImpact {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        viewStore.send(.shouldPlayScrollImpact(value: false))
                    }
                    return
                }
                viewStore.send(.setHymnScrollDrag(value: Float(currentState.translation.width)))
            }.onEnded { value in
                viewStore.send(.setHymnScrollDrag(value: Float(0))) 
                viewStore.send(.shouldPlayScrollImpact(value: true))
                if value.startLocation.x < value.location.x {
                    guard
                        value.translation.width > 50
                    else { return }
                    viewStore.send(.previousHymn)
                } else {
                    guard
                        value.translation.width < -50
                    else { return }
                    viewStore.send(.nextHymn)
                }
            })
        }
    }
    
    private func getOffSet(_ viewStore: ViewStore<HymnState, HymnAction>) -> Float {
        let totalCanvasWidth: CGFloat = (cardWidth * numberOfItems) + totalSpacing
        let xOffsetToShift = (totalCanvasWidth - UIScreen.main.bounds.width) / 2
        let leftPadding = 32 + spacing
        let totalMovement = cardWidth + spacing
        
        let activeOffset = xOffsetToShift + (leftPadding) - (totalMovement * CGFloat(viewStore.scrollViewState.activeViewIndex))
        let nextOffset = xOffsetToShift + (leftPadding) - (totalMovement * CGFloat(viewStore.scrollViewState.activeViewIndex) + 1)
        
        var calculatedOffset = Float(activeOffset)
        
        if (calculatedOffset != Float(nextOffset)) {
            calculatedOffset = Float(activeOffset) + viewStore.scrollViewState.screenDrag
        }
        return calculatedOffset
    }
}

struct Canvas<Content : View> : View {
    let content: Content
    
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .background(Color.clear)
            .background(
                Color(UIColor.systemBackground)
                    .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                    .shadow(
                        color: Color(uiColor: .systemBackground),
                        radius: 3)
                    .mask(Rectangle().padding(.bottom, -10))
            )
    }
}



struct HymnScrollItem<Content: View>: View {
    var id: Int
    var content: Content
    
    @inlinable
    public init(id: Int,
                @ViewBuilder _ content: () -> Content) {
        self.content = content()
        self.id = id
    }
    
    var body: some View {
        content
            .background(Color.clear)
    }
}



