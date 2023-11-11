//
//  VMError.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public struct VMError: Error {
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
