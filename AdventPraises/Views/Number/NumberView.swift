//
//  NumberView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI


struct NumberView: View {
    
    @EnvironmentObject var store: Store
    @StateObject var viewModel = NumberViewModel()
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                HStack {
                    Spacer()
                    Text(store.state.activeNumber)
                        .bold()
                        .tracking(10)
                        .font(.system(size: 52))
                }.padding(.init(
                    bottom: 40,
                    trailing: 60))
            }
            ForEach(viewModel.grid, id: \.self) { row in
                HStack(spacing: 80) {
                    ForEach(row, id: \.self) { item in
                        NumberPadButton(item: item)
                        .simultaneousGesture(LongPressGesture()
                            .onEnded { _ in
                                store.send(.didLongPress(.delete))
                            }).highPriorityGesture(TapGesture()
                                .onEnded { _ in
                                    store.send(.didPress(item))
                                })
                    }
                }
            }
        }
        .padding(.all)
    }
}

struct NumberView_Previews: PreviewProvider {
    static var previews: some View {
        NumberView()
            .environmentObject(Store.live)
    }
}
