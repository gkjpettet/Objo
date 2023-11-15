//
//  ParserError.swift
//  
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public struct ParserError: Error {    
    /// The location in the token stream that the error occurred.
    /// May be nil in the edge case that the parser was not initialised correctly.
    public let location: Token?
    
    /// The error message.
    public let message: String
    
    public init(message: String, location: Token?) {
        self.message = message
        self.location = location
    }
    
    /// Returns a formatted string for displaying this error in the console.
    public var pretty: String {
        return "[\(location?.line ?? -1), \(location?.start ?? -1)]: \(message)"
    }
}
