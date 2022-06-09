//
//  AppState.swift
//  AdventPraises
//
//  Created by Malcolm on 6/8/22.
//

import Foundation

struct AppState {
    var selectedTab: Tab = .number
    var activeNumber: String = ""
    var selectedNumber: String = ""
    var numberPadLayout: [[NumberPadItem]] = NumberPadItem.standardLayout
}
