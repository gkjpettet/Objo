//
//  BooleanToken.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct BooleanToken: Token {
    /// The token's lexeme.
    public let lexeme: String?
    /// The 1-based line the token occurred on.
    public let line: Int
    /// The 0-based character index of the start of this token.
    public let start: Int
    /// The ID of the script this token came from.
    public let scriptId: Int
    public let type: TokenType = .boolean
    /// The actual value of this literal.
    public let value: Bool
    
    public init(value: Bool, start: Int, line: Int, lexeme: String, scriptId: Int) {
        self.start = start
        self.line = line
        self.lexeme = lexeme
        self.scriptId = scriptId
        self.value = value
    }
}
