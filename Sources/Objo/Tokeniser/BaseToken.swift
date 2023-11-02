//
//  BaseToken.swift
//
//
//  Created by Garry Pettet on 28/10/2023.
//

import Foundation

public struct BaseToken: Token {
    public let lexeme: String?
    public let line: Int
    public let start: Int
    public let scriptId: Int
    public let type: TokenType
    
    public init(type: TokenType, start: Int, line: Int, lexeme: String?, scriptId: Int) {
        self.type = type
        self.start = start
        self.line = line
        self.lexeme = lexeme
        self.scriptId = scriptId
    }
}
