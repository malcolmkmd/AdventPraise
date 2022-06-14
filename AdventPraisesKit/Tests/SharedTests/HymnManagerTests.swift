//
//  HymnManagerTests.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

import XCTest
@testable import Shared

final class HymnManagerTests: XCTestCase {
    
    func testLoadEnglishJson() throws {
        let englishHymns = HymnManager().loadJsonHymns(for: .english)
        XCTAssert(!englishHymns.isEmpty)
        XCTAssertEqual(englishHymns.count, 300)
    }
    
}
