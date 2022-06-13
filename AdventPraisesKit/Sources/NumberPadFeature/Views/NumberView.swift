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
    
    @ViewBuilder
    private func SearchTextField(_ viewStore: ViewStore<NumberPadState, NumberPadAction>) -> some View {
        Button(action: {}) {
            VStack(alignment: .leading) {
                Divider()
                HStack {
                    Image(.search)
                        .isHidden(!viewStore.isSearch, remove: true)
                    Text(viewStore.displayedText)
                        .animation(.spring(dampingFraction: 1))
                }
                .font(.largeTitle)
                .foregroundColor(viewStore.isSearch ? .gray : Color(.systemBlue))
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
            .isHidden(viewStore.isSearch, remove: true)
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
                                            viewStore.send(.didTap(item))
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

struct NumberPadView_Previews: PreviewProvider {
    static var previews: some View {
        NumberPadView(store: .init(initialState: NumberPadState(), reducer: numberPadReducer, environment: NumberPadEnvironment())).preferredColorScheme(.dark)
    }
}
