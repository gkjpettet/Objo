//
//  ReturnStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ReturnStmt: Stmt {
    /// The `return` keyword token.
    public var location: Token
    /// Optional value to return.
    public let value: Expr?
    
    public init(keyword: Token, value: Expr?) {
        self.location = keyword
        self.value = value
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitReturn(stmt: self)
    }
}
