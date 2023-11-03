//
//  LogicalExpr.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct LogicalExpr: Expr {
    /// The left hand operand.
    public let left: Expr
    /// The location of the logical operator in the original token stream.
    public var location: Token
    /// The type of operator for this logical expression.
    public let op: TokenType
    /// The right hand operand.
    public let right: Expr
    
    public init(left: Expr, op: Token, right: Expr) {
        self.left = left
        self.location = op
        self.op = op.type
        self.right = right
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitLogical(expr: self)
    }
}
