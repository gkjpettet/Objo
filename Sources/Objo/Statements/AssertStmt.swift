//
//  AssertStmt.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct AssertStmt: Stmt {
    /// The condition to assert is `true`.
    public let condition: Expr
    /// The `assert` keyword token.
    public var location: Token
    /// The message to display if `condition` evaluates to `false`.
    public let message: Expr
    
    public init(condition: Expr, message: Expr, location: Token) {
        self.condition = condition
        self.location = location
        self.message = message
    }
    
    /// A visitor is visiting this statement.
    public func accept(_ visitor: StmtVisitor) {
        return visitor.visitAssertStmt(stmt: self)
    }
}
