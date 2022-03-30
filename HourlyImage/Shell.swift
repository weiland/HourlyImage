//
//  Shell.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import Foundation

class Shell {
    static func safeShell(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["sh", "-c", command]
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    static func scp(localDirectory: String, server: String, remoteDirectory: String, sshKeyName: String) {
        do {
            let scpCommand = "scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i \(localDirectory)/\(sshKeyName) \(localDirectory)/*.jpg \(server):\(remoteDirectory)"
            print(try safeShell("\(scpCommand)\(Config.Shell.deleteLocalImages ? " && rm \(localDirectory)/*.jpg" : "") && echo 'finshed scp' || echo 'Error during scp upload'"))
            debugPrint(try safeShell("ls -la \(localDirectory)"))
        }
        catch {
            print("Shell-Error: \(error)")
        }
    }
}
