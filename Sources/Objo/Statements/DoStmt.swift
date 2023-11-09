//
//  DoStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct DoStmt: Stmt {
    /// The body of statements to execute each iteration.
    public let body: BlockStmt
    /// The loop condition to evaluate.
    public let condition: Expr
    /// The `do` keyword token.
    public var location: Token
    
    public init(condition: Expr, body: BlockStmt, keyword: Token) {
        self.condition = condition
        self.body = body
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitDo(stmt: self)
    }
}
