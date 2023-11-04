//
//  CallExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct CallExpr: Expr {
    /// The arguments to the call.
    public let arguments: [Expr]
    /// The callee.
    public let callee: Expr
    /// The opening parenthesis.
    public var location: Token
    
    public init(callee: Expr, arguments: [Expr], lparen: Token) {
        self.callee = callee
        self.arguments = arguments
        self.location = lparen
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitCall(expr: self)
    }
}
