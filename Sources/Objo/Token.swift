//
//  File.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public struct Token {
    
    /// This token's optional lexeme.
    public let lexeme: String?
    /// The 1-based line number this token begins on.
    public let line: Int
    /// The 0-based index of the first character of this token in the original source code.
    public let start: Int
    /// The ID of the script this token belongs to.
    public let scriptId: Int
    /// The type of token.
    public let type: TokenType
    
    public init(type: TokenType, start: Int, line: Int, lexeme: String?, scriptId: Int) {
        self.type = type
        self.start = start
        self.line = line
        self.lexeme = lexeme
        self.scriptId = scriptId
    }
    
}
