//
//  NumberLiteral.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct NumberLiteral: Expr {
    /// `true` if this number is an integer.
    public let isInteger: Bool
    /// The location of the literal in the original token stream.
    public var location: Token
    /// The actual value of the number.
    public let value: Double
    
    public init(token: NumberToken) {
        self.isInteger = token.isInteger
        self.location = token
        self.value = token.value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitNumber(expr: self)
    }
}
