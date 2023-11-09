//
//  ConstructorDeclStmt.swift
//
//
//  Created by Garry Pettet on 05/11/2023.
//

import Foundation

public struct ConstructorDeclStmt: Stmt {
    /// The number of parameters this constructor expects.
    public let arity: Int
    /// This constructor's body.
    public let body: BlockStmt
    /// The name of the class this constructor belongs to.
    public let className: String
    /// The `constructor` keyword token.
    public var location: Token
    /// This constructor's parameter identifier tokens.
    public let parameters: [Token]
    /// This constructor's signature.
    public let signature: String
    
    public init(className: String, parameters: [Token], body: BlockStmt, constructorKeyword: Token) throws {
        self.className = className
        self.parameters = parameters
        self.arity = parameters.count
        self.body = body
        self.location = constructorKeyword
        self.signature = try Objo.computeSignature(name: "constructor", arity: arity, isSetter: false)
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitConstructorDeclaration(stmt: self)
    }
}
