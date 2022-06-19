//
//  HymnTests.swift
//  AdventPraisesTests
//
//  Created by Malcolm on 6/19/22.
//

import XCTest
@testable import Core
@testable import HymnFeature

final class HymnTests: XCTestCase {

    func testEnglishJsonFormat() throws {
        let hymns = HymnalClient.loadJsonHymns()
        var malformedJson: [Hymn] = []
        for hymn in hymns {
            if hymn.lyrics.contains("CHORUS") {
                if hymn.continousFormat == hymn.normalFormat {
                    malformedJson.append(hymn)
                }
            }
        }
        XCTAssertEqual(malformedJson.count, 0)
        XCTAssertEqual(malformedJson, [])
    }

    

}
