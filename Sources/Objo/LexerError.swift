//
//  LexerError.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public struct LexerError: Error {
    public enum ErrorType {
        case syntaxError
        case unexpectedCharacter
    }
    
    public let line: Int
    public let message: String
    public let scriptId: Int
    public let start: Int
    public let type: ErrorType

    public init(line: Int, message: String, scriptId: Int, start: Int, type: ErrorType) {
        self.line = line
        self.message = message
        self.scriptId = scriptId
        self.start = start
        self.type = type
    }
}
