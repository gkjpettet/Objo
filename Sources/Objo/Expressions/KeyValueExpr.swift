//
//  KeyValueExpr.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct KeyValueExpr: Expr {
    /// The key (as an expression to evaluate).
    public let key: Expr
    /// The colon (`:`) token.
    public var location: Token
    /// The value (as an expression to evaluate).
    public let value: Expr
    
    public init(colon: Token, key: Expr, value: Expr) {
        self.key = key
        self.location = colon
        self.value = value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitKeyValue(expr: self)
    }
}
