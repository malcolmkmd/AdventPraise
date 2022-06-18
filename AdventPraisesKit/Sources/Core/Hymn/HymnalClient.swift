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
                         lyrics: "Watchman, blow the gospel trumpet,<br/>Evry soul a warning give;<br/>Whosoever hears the message <br/>May repent, and turn, and live. <br/><br/><b>CHORUS</b><br/>Blow the trumpet, trusty watchman,<br/>Blow it loud o'er land and sea…<br/>(loud o'er land and sea)<br/>God commissions, sound the message!<br/>Ev'ry captive may be free. <br/><br/>Sound it loud o'er ev'ry hilltop,<br/>Gloomy shade, and sunny plain;<br/>Ocean depths repeat the message,<br/>full salvation's glad refrain. <br/><br/>Sound it in the hedge and highway,<br/>Earth's dark sports where exiles roam;<br/>Let it tell all things are ready, <br/>Father waits to welcome home. <br/><br/>Sound it for the heavy laden,<br/>Weary, longing to be free.<br/>Sound a Saviour's invitation,<br/>Sweetly saying, \"Come to me\". <br/><br/>")
                ]
            default:
                return [
                    Hymn(id: "Mlindi, vuthel' icilongo,Xwayis",
                         title: "Mlindi, vuthel' icilongo,Xwayis",
                         subtitle: "(Vern-1, AH-350, SDAH-368)",
                         lyrics: "Watchman, blow the gospel trumpet,<br/>Evry soul a warning give;<br/>Whosoever hears the message <br/>May repent, and turn, and live. <br/><br/><b>CHORUS</b><br/>Blow the trumpet, trusty watchman,<br/>Blow it loud o'er land and sea…<br/>(loud o'er land and sea)<br/>God commissions, sound the message!<br/>Ev'ry captive may be free. <br/><br/>Sound it loud o'er ev'ry hilltop,<br/>Gloomy shade, and sunny plain;<br/>Ocean depths repeat the message,<br/>full salvation's glad refrain. <br/><br/>Sound it in the hedge and highway,<br/>Earth's dark sports where exiles roam;<br/>Let it tell all things are ready, <br/>Father waits to welcome home. <br/><br/>Sound it for the heavy laden,<br/>Weary, longing to be free.<br/>Sound a Saviour's invitation,<br/>Sweetly saying, \"Come to me\". <br/><br/>")
                ]
        }
    }
    
}
