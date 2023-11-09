//
//  ExpressionStmt.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct ExpressionStmt: Stmt {
    /// The actual expression to be evaluated.
    public let expression: Expr
    /// The first token of this expression.
    public var location: Token
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitExpressionStmt(stmt: self)
    }
    
    public init(expression: Expr, location: Token) {
        self.expression = expression
        self.location = location
    }
}
