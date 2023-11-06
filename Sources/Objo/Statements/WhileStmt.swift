//
//  WhileStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct WhileStmt: Stmt {
    /// The body of statements to execute each iteration.
    public let body: BlockStmt
    /// The condition to evaluate.
    public let condition: Expr
    /// The `while` keyword token.
    public var location: Token
    
    public init(condition: Expr, body: BlockStmt, whileKeyword: Token) {
        self.condition = condition
        self.body = body
        self.location = whileKeyword
    }
    
    public func accept(_ visitor: StmtVisitor) {
        visitor.visitWhile(stmt: self)
    }
}
