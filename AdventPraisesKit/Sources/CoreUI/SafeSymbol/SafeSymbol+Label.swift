//
//  SFSymbol+Label.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

public extension Label where Title == Text, Icon == Image {
    
    init(_ titleKey: LocalizedStringKey, safeSymbol: SFSymbol) {
        self.init(titleKey, image: safeSymbol.rawValue)
    }
    
    @_disfavoredOverload
    init<S>(title: S, safeSymbol: SFSymbol) where S: StringProtocol {
        self.init(title, image: safeSymbol.rawValue)
    }
    
}
