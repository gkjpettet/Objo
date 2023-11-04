//
//  IsExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct IsExpr: Expr {
    /// The `is` keyword.
    public var location: Token
    /// The expression to evaluate to a type name to compare against.
    public let type: Expr
    /// The value to the left of the `is` keyword.
    public let value: Expr
    
    public init(value: Expr, type: Expr, isKeyword: Token) {
        self.value = value
        self.type = type
        self.location = isKeyword
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitIs(expr: self)
    }
}
