//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import Core
import CoreUI
import SwiftUI
import HymnalPickerFeature
import ComposableArchitecture

public struct NumberPadView: View {
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    let store: Store<NumberPadState, NumberPadAction>
    
    public init(store: Store<NumberPadState, NumberPadAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                NavigationBar(
                    title: viewStore.activeHymnal.title,
                    leadingAction: { viewStore.send(.didTapHymnPicker) },
                    trailingAction: {})
                .transaction { $0.animation = nil }
                Spacer()
                SearchTextField(viewStore)
                NumberPad(viewStore)
            }
        }
    }
    
    @ViewBuilder
    private func SearchTextField(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        Button(action: { searchAction(viewStore) }) {
            VStack(alignment: .leading) {
                Divider()
                HStack {
                    Image(.search)
                        .isHidden(viewStore.hasActiveNumber, remove: true)
                    Text(viewStore.displayedText)
                }
                .font(.bodyCustom)
                .foregroundColor(!viewStore.hasActiveNumber ? .gray : Color(.systemBlue))
                Divider()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 60)
        }.buttonStyle(.bounce())
    }
    
    private func searchAction(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) {
        viewStore.hasActiveNumber
        ? viewStore.send(.presentActiveNumber)
        : viewStore.send(.didTapSearchField)
    }
    
    @ViewBuilder
    private func NumberPad(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        VStack {
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
            Button(action: {}) {
                HStack {
                    Spacer()
                    Text("GO")
                        .font(.bodyCustom)
                        .foregroundColor(Color(UIColor.systemBackground))
                    Spacer()
                }
            }
            .padding(.top, 10)
            .frame(height: 40)
            .background(
                Color(UIColor.tintColor)
                    .clipShape(CustomCorners(corners: [.topLeft, .topRight], radius: 10))
                    .edgesIgnoringSafeArea(.all)
            )
            .isHidden(!viewStore.hasActiveNumber)
            .transition(AnyTransition.asymmetric(
                insertion: .move(edge: .bottom),
                removal: .move(edge: .bottom)
                    .combined(with: .opacity)
            ))
        }
        
    }
    
    private func buttonWidth() -> CGFloat {
        (UIScreen.main.bounds.width - (5*12)) / 4
    }
}

#if DEBUG
struct NumberPadView_Previews: PreviewProvider {
    static var previews: some View {
        NumberPadView(store: .init(initialState: NumberPadState(hymns: HymnalClient.mockHymns(), activeHymnal: .english), reducer: numberPadReducer, environment: NumberPadEnvironment())).preferredColorScheme(.dark)
    }
}
#endif

