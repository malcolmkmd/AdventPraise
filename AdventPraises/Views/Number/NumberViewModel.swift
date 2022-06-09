//
//  NumberViewModel.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Foundation

final class NumberViewModel: NSObject, ObservableObject {
    
    public var grid: [[NumberPadItem]] = NumberPadItem.standardLayout
    
}
