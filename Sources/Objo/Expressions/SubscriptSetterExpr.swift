//
//  SubscriptSetterExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SubscriptSetterExpr: Expr {
    /// The indices to the subscript setter. There is **always** at least one index.
    public let indexes: [Expr]
    /// The opening square bracket.
    public var location: Token
    /// The operand to call the `operator_subscript` setter method on.
    public let operand: Expr
    /// The signature of this subscript setter call.
    public let signature: String
    /// The value to assign.
    public let valueToAssign: Expr
    
    public init(lsquare: Token, operand: Expr, indexes: [Expr], valueToAssign: Expr) throws {
        self.location = lsquare
        self.operand = operand
        self.indexes = indexes
        self.valueToAssign = valueToAssign
        
        // +1 since indexes excludes the value to assign.
        self.signature = try Objo.computeSubscriptSignature(arity: indexes.count + 1, isSetter: true)
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitSubscriptSetter(expr: self)
    }
}
