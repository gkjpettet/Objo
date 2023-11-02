//
//  Token.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public protocol Token {
    /// This token's optional lexeme.
    var lexeme: String? { get }
    /// The 1-based line number this token begins on.
    var line: Int { get }
    /// The 0-based index of the first character of this token in the original source code.
    var start: Int { get }
    /// The ID of the script this token belongs to.
    var scriptId: Int { get }
    /// The type of token.
    var type: TokenType { get }
}
