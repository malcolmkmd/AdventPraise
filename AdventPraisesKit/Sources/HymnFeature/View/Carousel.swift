//
//  Carousel.swift
//  
//
//  Created by Malcolm on 6/20/22.
//

import SwiftUI
import ComposableArchitecture

struct Carousel<Items : View> : View {
    let items: Items
    let numberOfItems: CGFloat
    let spacing: CGFloat
    let totalSpacing: CGFloat
    let cardWidth: CGFloat
    
    @GestureState var isDetectingLongPress = true
    
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>,
                numberOfItems: CGFloat,
                spacing: CGFloat,
                @ViewBuilder _ items: () -> Items) {
        self.store = store
        self.items = items()
        self.numberOfItems = numberOfItems
        self.spacing = spacing
        self.totalSpacing = (numberOfItems - 1) * spacing
        self.cardWidth = UIScreen.main.bounds.width
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            HStack(alignment: .center, spacing: spacing) {
                items
            }
            .background(Color(uiColor: .clear))
            .offset(x: CGFloat(getOffSetX(viewStore)), y: 0)
            .gesture(DragGesture().updating($isDetectingLongPress) { currentState, gestureState, transaction in
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                let offSetX = getOffSetX(viewStore)
                
                if offSetX > -50 && offSetX < 50 {
                    viewStore.send(.shouldPlayScrollImpact(left: true, right: true))
                }
                
                if getOffSetX(viewStore) == -100 {
                    if viewStore.scrollViewState.shouldPlayRightImpact {
                        impactMed.impactOccurred()
                        viewStore.send(.shouldPlayScrollImpact(left: true, right: false))
                    }
                }
                
                if getOffSetX(viewStore) == 100 {
                    if viewStore.scrollViewState.shouldPlayLeftImpact {
                        impactMed.impactOccurred()
                        viewStore.send(.shouldPlayScrollImpact(left: false, right: true))
                    }
                }
                viewStore.send(.setHymnScrollDrag(value: Float(currentState.translation.width)))
            }.onEnded { value in
                viewStore.send(.setHymnScrollDrag(value: Float(0)))
                viewStore.send(.shouldPlayScrollImpact(left: true, right: true))
                
                if value.startLocation.x < value.location.x {
                    guard
                        value.translation.width > 80
                    else { return }
                    viewStore.send(.shouldPlayScrollImpact(left: true, right: false))
                    viewStore.send(.previousHymn, animation: .default)
                } else {
                    guard
                        value.translation.width < -80
                    else { return }
                    viewStore.send(.shouldPlayScrollImpact(left: false, right: true))
                    viewStore.send(.nextHymn, animation: .default)
                }
            })
        }
    }
    
    private func getOffSetX(_ viewStore: ViewStore<HymnState, HymnAction>) -> Float {
        let totalCanvasWidth: CGFloat = (cardWidth * numberOfItems) + totalSpacing
        let xOffsetToShift = (totalCanvasWidth - UIScreen.main.bounds.width) / 2
        let leftPadding: CGFloat = 0
        let totalMovement = cardWidth + spacing
        
        let activeOffset = xOffsetToShift + CGFloat((leftPadding)) - (totalMovement * CGFloat(viewStore.scrollViewState.activeViewIndex))
        let nextOffset = xOffsetToShift + (leftPadding) - (totalMovement * CGFloat(viewStore.scrollViewState.activeViewIndex) + 1)
        
        var calculatedOffset = Float(activeOffset)
        
        if (calculatedOffset != Float(nextOffset)) {
            calculatedOffset = Float(activeOffset) + viewStore.scrollViewState.screenDrag
        }
        if calculatedOffset <= -100 {
            return -100
        }
        if calculatedOffset < 20 && calculatedOffset > -20 {
            return 0
        }
        return calculatedOffset > 100 ? 100 : calculatedOffset
    }
}
