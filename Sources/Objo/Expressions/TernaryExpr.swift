//
//  TernaryExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct TernaryExpr: Expr {
    /// The condition to evaluate.
    public let condition: Expr
    /// The expression to evaluate if `condition` evaluates to false.
    public let elseBranch: Expr
    /// The `if` keyword token.
    public var location: Token
    /// The expression to evaluate if `condition` evaluates to true.
    public let thenBranch: Expr
    
    public init(condition: Expr, thenBranch: Expr, elseBranch: Expr, ifKeyword: Token) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.location = ifKeyword
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitTernary(expr: self)
    }
}
