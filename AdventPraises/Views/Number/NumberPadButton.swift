//
//  NumberPadButton.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import SwiftUI

struct NumberPadButton: View {
    
    let item: NumberPadItem
    
    init(item: NumberPadItem) {
        self.action = action
        self.item = item
    }
    
    var body: some View {
        if let symbol = item.symbol {
            Image(symbol)
        } else if case let .number(value) = item {
            Text("\(value)")
        }
        .fontWeight(.semibold)
        .font(.system(size: 32))
        .foregroundColor(Color.gray)
        .frame(maxWidth: 80, maxHeight: 40)
    }
}

struct MainTabBarView_Previews2: PreviewProvider {
    static var previews: some View {
        RootTabBarView().environmentObject(Store(initialState: AppState(), reducer: appReducer(state:action:)))
    }
}
