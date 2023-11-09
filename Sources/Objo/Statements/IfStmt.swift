//
//  IfStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct IfStmt: Stmt {
    /// The `if` condition to evaluate.
    public let condition: Expr
    /// Optional `else` branch statement.
    public let elseBranch: Stmt?
    /// The location of the `if` keyword.
    public var location: Token
    /// The statement(s) to execute if `condition` evaluates to `true` at runtime.
    public let thenBranch: Stmt
    
    public init(condition: Expr, thenBranch: Stmt, elseBranch: Stmt?, ifKeyword: Token) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.location = ifKeyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitIf(stmt: self)
    }
}
