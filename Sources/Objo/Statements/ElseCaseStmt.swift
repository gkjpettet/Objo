//
//  ElseCaseStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ElseCaseStmt: Stmt {
    /// This else case's body.
    public let body: BlockStmt
    /// The location of the `else` keyword.
    public var location: Token
    
    public init(body: BlockStmt, keyword: Token) {
        self.body = body
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitElseCase(stmt: self)
    }
}
