//
//  ForStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ForStmt: Stmt {
    /// The body of the `for` loop.
    public let body: BlockStmt
    /// Optional loop condition.
    public let condition: Expr?
    /// Optional expression to evaluate at the end of each loop iteration.
    public let increment: Expr?
    /// Optional loop initialiser.
    public let initialiser: Stmt?
    /// The location of the `for` keyword
    public var location: Token
    
    public init(initialiser: Stmt?, condition: Expr?, increment: Expr?, body: BlockStmt, forKeyword: Token) {
        self.initialiser = initialiser
        self.condition = condition
        self.increment = increment
        self.body = body
        self.location = forKeyword
    }
    
    public func accept(_ visitor: StmtVisitor) {
        visitor.visitFor(stmt: self)
    }
}
