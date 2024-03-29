//
//  NumberPadButton.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Core
import SwiftUI

struct NumberPadButton: View {
    
    let item: NumberPadItem
    
    init(item: NumberPadItem) {
        self.item = item
    }
    
    var body: some View {
        Button(action: {}, label: {
            if let symbol = item.symbol {
                Image(symbol).font(.customBody)
                    .opacity(item == .empty ? 0.1 : 1)
            } else if case let .number(value) = item {
                Text("\(value)")
                    .font(.customTitle3)
            }
        })
        .contentShape(Rectangle())
        .foregroundColor(Color(.systemBlue))
    }
}

struct NumberPadButton_Preview: PreviewProvider {
    static var previews: some View {
        NumberPadButton(item: .number(9))
    }
}
