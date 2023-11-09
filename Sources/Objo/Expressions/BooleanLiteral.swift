//
//  BooleanLiteral.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct BooleanLiteral: Expr {
    /// The location of the boolean in the original token stream.
    public var location: Token
    /// This boolean literal's actual value.
    public let value: Bool
    
    public init(token: BooleanToken) {
        self.location = token
        self.value = token.value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitBoolean(expr: self)
    }
}
