//
//  NavigationBar.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import SwiftUI

public struct NavigationBar: View {
    
    private let title: String
    private let LeadingIcon: Image
    private let TrailingIcon: Image
    private let leadingAction: () -> ()
    private let trailingAction: () -> ()
    
    public init(title: String,
                leadingIcon: Image = Image(.bookClosed),
                trailingIcon: Image = Image(.menu),
                leadingAction: @escaping () -> (),
                trailingAction: @escaping () -> ()) {
        self.title = title
        self.LeadingIcon = leadingIcon
        self.TrailingIcon = trailingIcon
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
    }
    
    public var body: some View {
        HStack {
            Button(action: leadingAction) {
                HStack {
                    LeadingIcon
                        .foregroundColor(Color(UIColor.tintColor))
                    Text(title)
                        .lineLimit(1)
                }
            }
            .font(.titleCustom)
            .buttonStyle(.bounce())
            Spacer()
            Button(action: trailingAction) {
                TrailingIcon
            }
            .font(.titleCustom)
            .buttonStyle(.bounce(scale: 0.7))
        }
        .padding(.all, 16)
    }
    
}

struct NavigationBar_Previews: PreviewProvider {
    
    static var previews: some View {
        NavigationBar(
            title: "Advent Praises",
            leadingAction: {},
            trailingAction: {})
    }
}
