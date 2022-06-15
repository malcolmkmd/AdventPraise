//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI
import ComposableArchitecture

public struct NumberPadView: View {
    
    let store: Store<NumberPadState, NumberPadAction>
    
    public init(store: Store<NumberPadState, NumberPadAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                NavigationBar(viewStore)
                Spacer()
                SearchTextField(viewStore)
                NumberPad(viewStore)
            }
        }
    }
    
    @ViewBuilder
    private func NavigationBar(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        HStack {
            Button(action: { viewStore.send(.changeHymnal(viewStore.activeHymnal == .english ? .zulu : .english)) }) {
                HStack {
                    Image(.bookClosed)
                        .font(.body)
                    Text(viewStore.activeHymnal.title)
                        .lineLimit(1)
                        .font(.body)
                }
            }.buttonStyle(.bounce())
            Spacer()
            Button(action: {}) {
                Image(.gearshapeFill)
                    .font(.title)
            }.buttonStyle(.bounce(scale: 0.7))
        }.padding(.all, 16)
    }
    
    @ViewBuilder
    private func SearchTextField(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        Button(action: { viewStore.send(.didTapSearchField) }) {
            VStack(alignment: .leading) {
                Divider()
                HStack {
                    Image(.search)
                        .isHidden(!viewStore.hasActiveNumber, remove: true)
                    Text(viewStore.displayedText)
                }
                .font(.largeTitle)
                .foregroundColor(viewStore.hasActiveNumber ? .gray : Color(.systemBlue))
                Divider()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 60)
        }.buttonStyle(.bounce())
    }
    
    @ViewBuilder
    private func NumberPad(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        VStack {
            Button(action: {}) {
                HStack {
                    Spacer()
                    Text("GO")
                        .font(.largeTitle)
                    Spacer()
                }
            }
            .background(Color(.systemBackground))
            .isHidden(viewStore.hasActiveNumber)
            .transition(.slide)
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
                                            if
                                                item == .delete,
                                                viewStore.activeNumber.count == 1 {
                                                viewStore.send(.didTap(item), animation: .spring())
                                            } else {
                                                viewStore.send(.didTap(item))
                                            }
                                            
                                        })
                        }
                    }
                }
            }
        }
        
    }
    
    private func buttonWidth() -> CGFloat {
        (UIScreen.main.bounds.width - (5*12)) / 4
    }
}


struct BounceButtonStyle: ButtonStyle {
    
    let scale: CGFloat
    
    init(scale: CGFloat = 0.97) {
        self.scale = scale
    }
    
    func makeBody(configuration: Configuration) -> some View {
        return configuration
            .label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeIn, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static func bounce(scale: CGFloat = 0.97) -> BounceButtonStyle {
        return BounceButtonStyle(scale: scale)
    }
}

#if DEBUG
//struct NumberPadView_Previews: PreviewProvider {
//    static var previews: some View {
//        NumberPadView(store: .init(initialState: NumberPadState(), reducer: numberPadReducer, environment: NumberPadEnvironment())).preferredColorScheme(.dark)
//    }
//}
#endif

