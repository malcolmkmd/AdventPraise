//
//  File.swift
//  
//
//  Created by Malcolm on 6/24/22.
//

import Foundation
import PackagePlugin

@main
struct GenerateContributors: CommandPlugin {
    
    func performCommand(context: PackagePlugin.PluginContext,
                        arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--pretty=format:- %an"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        
        let contributors = Set(output.components(separatedBy: .newlines))
        .sorted()
        .filter { !$0.isEmpty }
        try contributors.joined(separator: "\n").write(
            toFile: "Docs/CONTRIBUTORS.text",
            atomically: true,
            encoding: .utf8)
    }
    
}
