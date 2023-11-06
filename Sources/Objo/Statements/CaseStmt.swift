//
//  CaseStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct CaseStmt: Stmt {
    /// This case's body.
    public let body: BlockStmt
    /// The location of the `case` keyword.
    public var location: Token
    /// The values to evaluate
    public let values: [Expr]
    
    public init(values: [Expr], body: BlockStmt, keyword: Token) {
        self.values = values
        self.body = body
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) {
        visitor.visitCase(stmt: self)
    }
}
