//
//  NavigationBar.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import SwiftUI

public struct NavigationBar: View {
    
    @State private var title: String
    private var action: () -> ()
    
    public init(title: String,
                action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        HStack {
            Button(action: action) {
                HStack {
                    Image(.bookClosed)
                        .font(.body)
                    Text(title)
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
    
}

struct NavigationBar_Previews: PreviewProvider {
    
    static var previews: some View {
        NavigationBar(title: "Test", action: {})
    }
}
