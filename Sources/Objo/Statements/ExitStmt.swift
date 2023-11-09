//
//  ExitStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ExitStmt: Stmt {
    /// The `exit` keyword token.
    public var location: Token
    
    public init(exitKeyword: Token) {
        self.location = exitKeyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitExit(stmt: self)
    }
}
