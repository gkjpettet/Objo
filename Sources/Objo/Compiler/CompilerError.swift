//
//  CompilerError.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

public struct CompilerError: Error {
    /// The location in the token stream that the error occurred.
    /// May be nil in the edge case that the parser was not initialised correctly.
    public let location: Token?
    
    /// The error message.
    public let message: String
    
    public init(message: String, location: Token?) {
        self.message = message
        self.location = location
    }
}
