//
//  UnaryExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct UnaryExpr: Expr {
    /// The unary operator token.
    public var location: Token
    /// The operand for this unary operation.
    public let operand: Expr
    /// The unary operator type.
    public var operator_: TokenType { return location.type }
    
    public init(op: Token, operand: Expr) {
        self.location = op
        self.operand = operand
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitUnary(expr: self)
    }
}
