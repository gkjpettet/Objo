//
//  BareSuperInvocationExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct BareSuperInvocationExpr: Expr {
    /// Arguments to pass to the super's constructor. May be empty.
    public let arguments: [Expr]
    /// If `true` then the `super` keyword was followed by parentheses.
    public let hasParentheses: Bool
    /// The `super` token.
    public var location: Token
    
    public init(superKeyword: Token, arguments: [Expr], hasParentheses: Bool) {
        self.location = superKeyword
        self.arguments = arguments
        self.hasParentheses = hasParentheses
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitBareSuperInvocation(expr: self)
    }
}
