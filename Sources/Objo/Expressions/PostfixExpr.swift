//
//  PostfixExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct PostfixExpr: Expr {
    /// The postfix operator token.
    public var location: Token
    /// The operand for this postfix operation.
    public let operand: Expr
    /// The postfix operator type.
    public var operator_: TokenType { return location.type }
    
    public init(operand: Expr, op: Token) {
        self.operand = operand
        self.location = op
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitPostfix(expr: self)
    }
}
