//
//  ContinueStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ContinueStmt: Stmt {
    /// The location of the `continue` keyword.
    public var location: Token
    
    public init(keyword: Token) {
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitContinue(stmt: self)
    }
}
