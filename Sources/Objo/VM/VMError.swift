//
//  VMError.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public struct VMError: Error {
    /// A formatted version of this error for printing to the console.
    public var pretty: String {
        var output: [String] = ["", "Runtime error (line:\(line), id:\(scriptId))"]
        output.append(message)
        output.append("")
        output.append("Stack dump:")
        output.append(stackDump)
        output.append("")
        output.append("Stack trace:")
        output.append(stackTrace.joined(separator: "\n"))
        
        return output.joined(separator: "\n")
    }
    
    /// The line number triggering this error.
    public let line: Int
    
    /// The error message.
    public let message: String
    
    /// The ID of the script triggering this error.
    public let scriptId: Int
    
    /// A dump of the stack contents at the time of the error.
    public let stackDump: String
    
    /// A rudimentary tracing of the stack at the moment the VM error occurred.
    public let stackTrace: [String]
}
