//
//  SubscriptExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SubscriptExpr: Expr {
    /// The indices to the subscript call. There is **always** at least one index.
    public let indexes: [Expr]
    /// The opening square bracket.
    public var location: Token
    /// The operand to call `operator_subscript` on.
    public let operand: Expr
    /// The signature of this subscript call.
    public let signature: String
    
    public init(lsquare: Token, operand: Expr, indexes: [Expr]) throws {
        self.location = lsquare
        self.operand = operand
        self.indexes = indexes
        self.signature = try Objo.computeSubscriptSignature(arity: indexes.count, isSetter: false)
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitSubscript(expr: self)
    }
}
