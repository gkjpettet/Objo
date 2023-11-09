//
//  StringLiteral.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct StringLiteral: Expr {
    /// The location of the string in the original token stream.
    public var location: Token
    /// The actual string value.
    public let value: String
    
    public init(token: Token) {
        self.location = token
        self.value = token.lexeme!
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitString(expr: self)
    }
}
