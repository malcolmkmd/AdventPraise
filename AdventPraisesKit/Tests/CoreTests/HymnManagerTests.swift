//
//  HymnManagerTests.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

import XCTest
@testable import Core

final class HymnManagerTests: XCTestCase {
    
    func testLoadEnglishJson() throws {
        let englishHymns = HymnalClient().loadJsonHymns(for: .english)
        XCTAssert(!englishHymns.isEmpty)
        XCTAssertEqual(englishHymns.count, 300)
    }
    
}
