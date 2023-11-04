//
//  BlockStmt.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct BlockStmt: Stmt {
    /// The closing brace of this block.
    public let closingBrace: Token
    /// /// The location of this block's opening curly brace.
    public var location: Token
    /// This block's statements.
    public let statements: [Stmt]
    
    public init(statements: [Stmt], openingBrace: Token, closingBrace: Token) {
        self.statements = statements
        self.location = openingBrace
        self.closingBrace = closingBrace
    }
    
    public func accept(_ visitor: StmtVisitor) {
        visitor.visitBlock(stmt: self)
    }
}
