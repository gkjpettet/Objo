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
    public let lexeme: String?
    public let line: Int
    public let start: Int
    public let scriptId: Int
    public let type: TokenType
    /// The numeric value of this literal.
    public let value: Double
    
    public init(value: Double, isInteger: Bool, start: Int, line: Int, lexeme: String, scriptId: Int) {
        self.isInteger = isInteger
        self.type = .number
        self.start = start
        self.line = line
        self.lexeme = lexeme
        self.scriptId = scriptId
        self.value = value
    }
}
