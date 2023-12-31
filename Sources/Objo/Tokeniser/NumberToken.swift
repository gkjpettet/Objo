//
//  NumberToken.swift
//
//
//  Created by Garry Pettet on 28/10/2023.
//

import Foundation

public struct NumberToken: Token {
    /// `true` if the number literal is an integer.
    public let isInteger: Bool
    /// The token's lexeme.
    public let lexeme: String?
    /// The 1-based line the token occurred on.
    public let line: Int
    /// The 0-based character index of the start of this token.
    public let start: Int
    /// The ID of the script this token came from.
    public let scriptId: Int
    public let type: TokenType = .number
    /// The numeric value of this literal.
    public let value: Double
    
    public init(value: Double, isInteger: Bool, start: Int, line: Int, lexeme: String, scriptId: Int) {
        self.isInteger = isInteger
        self.start = start
        self.line = line
        self.lexeme = lexeme
        self.scriptId = scriptId
        self.value = value
    }
}
