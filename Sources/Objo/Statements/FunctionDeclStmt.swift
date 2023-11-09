//
//  FunctionDeclStmt.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct FunctionDeclStmt: Stmt {
    /// The function's body.
    public let body: BlockStmt
    /// The `function` keyword.
    public var location: Token
    /// The function's name as the identifier token in the source code.
    public let name: Token
    /// The function's parameters (may be empty).
    public let parameters: [Token]
    
    public init(name: Token, parameters: [Token], body: BlockStmt, funcKeyword: Token) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.location = funcKeyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitFuncDeclaration(stmt: self)
    }
}
