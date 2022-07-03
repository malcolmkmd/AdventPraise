//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/16/22.
//

import SwiftUI

struct SearchButton: View {
    
    let action: () -> ()
    var isActive: Bool
    let textColor: Color
    let activeTextColor: Color
    var displayedText: String
    
    init(action: @escaping () -> (),
         isActive: Bool,
         textColor: Color = Color(uiColor: .gray),
         activeTextColor: Color = Color(uiColor: .systemBlue),
         displayedText: String) {
        self.action = action
        self.isActive = isActive
        self.textColor = textColor
        self.activeTextColor = activeTextColor
        self.displayedText = displayedText
    }
    
    var body: some View {
        Button(action: {
            withAnimation { action() }
        }) {
            VStack(alignment: .leading) {
                HStack {
                    Image(.search)
                        .isHidden(isActive, remove: true)
                    Text(displayedText.isEmpty ? "Search for a hymn" : displayedText)
                    Spacer()
                }
                .font(.customTitle3)
                .contentShape(Rectangle())
                .foregroundColor(!isActive ? textColor : activeTextColor)
            }
        }.buttonStyle(.bounce())
    }
}
