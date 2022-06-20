//
//  File.swift
//  
//
//  Created by Malcolm on 6/20/22.
//

import SwiftUI

struct IdentifiableView<Content: View>: View {
    var id: Int
    var content: Content
    
    @inlinable
    public init(id: Int,
                @ViewBuilder _ content: () -> Content) {
        self.content = content()
        self.id = id
    }
    
    var body: some View {
        content
            .background(Color.clear)
    }
}
