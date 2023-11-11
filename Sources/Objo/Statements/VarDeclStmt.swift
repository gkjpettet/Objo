//
//  VarDeclStmt.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct VarDeclStmt: Stmt {
    /// The token representing this variable's name.
    public let identifier: Token
    
    /// The intialiser for this variable.
    public let initialiser: Expr
    
    /// The `var` keyword token.
    public var location: Token
    
    /// The variable's name.
    public var name: String { return identifier.lexeme! }
    
    public func accept(_ visitor: StmtVisitor) throws {
        return try visitor.visitVarDeclaration(stmt: self)
    }
    
    public init(identifier: Token, initialiser: Expr, location: Token) {
        self.identifier = identifier
        self.initialiser = initialiser
        self.location = location
    }
}
