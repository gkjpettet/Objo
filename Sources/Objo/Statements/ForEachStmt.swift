//
//  ForEachStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct ForEachStmt: Stmt {
    /// The statements to execute each iteration.
    public let body: BlockStmt
    /// The location of the `foreach` keyword.
    public var location: Token
    /// The loop counter identifier token.
    public let loopCounter: Token
    /// The range expression.
    public let range: Expr
    
    public init(foreachKeyword: Token, loopCounter: Token, range: Expr, body: BlockStmt) {
        self.location = foreachKeyword
        self.loopCounter = loopCounter
        self.range = range
        self.body = body
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitForEach(stmt: self)
    }
}
