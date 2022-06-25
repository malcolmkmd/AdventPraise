let arguments = ProcessInfo().arguments
if arguments.count < 3 {
    print("Missing arguments: Expected {} {}")
}

let (input, output) = (arguments[1], arguments[2])

struct Contents: Decodable {
    let images: [Image]
}

struct Image: Decodable {
    let filename: String?
}

var generatedCode = """
    import SwiftUI
    import Foundation
    
    """

try FileManager.default.contentsOfDirectory(atPath: input).forEach { dirent in
    guard dirent.hasSuffix("imageset") else { return }
    
    let contentsJsonURL = URL(fileURLWithPath: "\(input)/\(dirent)/Contents.json")
    let jsonData = try Data(contentsOf: contentsJsonURL)
    let assetCatalogContents = try JSONDecoder().decode(
        Contents.self,
        from: jsonData)
    let hasImage = assetCatalogContents.images.filter { $0.filename != nil }.isEmpty == false
    
    guard hasImage else { return }
    let basename = contentsJsonURL
        .deletingLastPathComponent()
        .deletingPathExtension()
        .lastPathComponent
    generatedCode.append("public let \(basename) = Image(\"\(basename)\", bundle: .module)\n")
}

try generatedCode.write(
    to: URL(fileURLWithPath: output),
    atomically: true,
    encoding: .utf8)
