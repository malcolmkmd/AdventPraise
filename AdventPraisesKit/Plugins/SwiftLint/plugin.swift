//
//  File.swift
//  
//
//  Created by Malcolm on 6/24/22.
//

import Foundation
import PackagePlugin

@main
struct SwiftLintPlugin: CommandPlugin {
    
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "swiftlint")
        let toolUrl = URL(fileURLWithPath: tool.path.string)
        
        for target in context.package.targets {
            guard let target = target as? SourceModuleTarget else { continue }
            
            let process = Process()
            process.executableURL = toolUrl
            process.arguments = [
                "\(target.directory)",
                "--fix",
                "--in-process-sourcekit"
            ]
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationReason == .exit && process.terminationStatus == 0 {
                print("Formatted the source code in \(target.directory).")
            }
            else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("swift-format invocation failed: \(problem)")
            }
        }
    }
}
