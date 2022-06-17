//
//  HymnalClient.swift
//  
//
//  Created by Malcolm on 6/14/22.
//

import Foundation

public struct HymnalClient {
    
    public static func loadJsonHymns(for language: Hymnal = .english) -> [Hymn] {
        guard let path = Bundle.core.path(
            forResource: language.rawValue,
            ofType: "json")
        else { return [] }
        do {
            let json = try Data(
                contentsOf: URL(fileURLWithPath: path),
                options: .alwaysMapped)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromPascalCase
            let hymns = try decoder.decode([Hymn].self, from: json)
            return hymns
        } catch let error {
            print(error)
        }
        return []
    }
    
    public static func mockHymns(for language: Hymnal = .english) -> [Hymn] {
        switch language {
            case .english:
                return [
                    Hymn(id: "Watchman Blow The Gospel Trumpet",
                         title: "Watchman Blow The Gospel Trumpet",
                         subtitle: "(Vern-1, AH-350, SDAH-368)",
                         lyrics: "Watchman, blow the gospel trumpet,<BON:nextLine/>Evry soul a warning give;<BON:nextLine/>Whosoever hears the message <BON:nextLine/>May repent, and turn, and live. <BON:nextLine/><BON:nextLine/><tt>CHORUS</tt><BON:nextLine/>Blow the trumpet, trusty watchman,<BON:nextLine/>Blow it loud o'er land and sea…<BON:nextLine/>(loud o'er land and sea)<BON:nextLine/>God commissions, sound the message!<BON:nextLine/>Ev'ry captive may be free. <BON:nextLine/><BON:nextLine/>Sound it loud o'er ev'ry hilltop,<BON:nextLine/>Gloomy shade, and sunny plain;<BON:nextLine/>Ocean depths repeat the message,<BON:nextLine/>full salvation's glad refrain. <BON:nextLine/><BON:nextLine/>Sound it in the hedge and highway,<BON:nextLine/>Earth's dark sports where exiles roam;<BON:nextLine/>Let it tell all things are ready, <BON:nextLine/>Father waits to welcome home. <BON:nextLine/><BON:nextLine/>Sound it for the heavy laden,<BON:nextLine/>Weary, longing to be free.<BON:nextLine/>Sound a Saviour's invitation,<BON:nextLine/>Sweetly saying, \"Come to me\". <BON:nextLine/><BON:nextLine/>")
                ]
            default:
                return [
                    Hymn(id: "Mlindi, vuthel' icilongo,Xwayis",
                         title: "Mlindi, vuthel' icilongo,Xwayis",
                         subtitle: "(Vern-1, AH-350, SDAH-368)",
                         lyrics: "Watchman, blow the gospel trumpet,<BON:nextLine/>Evry soul a warning give;<BON:nextLine/>Whosoever hears the message <BON:nextLine/>May repent, and turn, and live. <BON:nextLine/><BON:nextLine/><tt>CHORUS</tt><BON:nextLine/>Blow the trumpet, trusty watchman,<BON:nextLine/>Blow it loud o'er land and sea…<BON:nextLine/>(loud o'er land and sea)<BON:nextLine/>God commissions, sound the message!<BON:nextLine/>Ev'ry captive may be free. <BON:nextLine/><BON:nextLine/>Sound it loud o'er ev'ry hilltop,<BON:nextLine/>Gloomy shade, and sunny plain;<BON:nextLine/>Ocean depths repeat the message,<BON:nextLine/>full salvation's glad refrain. <BON:nextLine/><BON:nextLine/>Sound it in the hedge and highway,<BON:nextLine/>Earth's dark sports where exiles roam;<BON:nextLine/>Let it tell all things are ready, <BON:nextLine/>Father waits to welcome home. <BON:nextLine/><BON:nextLine/>Sound it for the heavy laden,<BON:nextLine/>Weary, longing to be free.<BON:nextLine/>Sound a Saviour's invitation,<BON:nextLine/>Sweetly saying, \"Come to me\". <BON:nextLine/><BON:nextLine/>")
                ]
        }
    }
    
}
