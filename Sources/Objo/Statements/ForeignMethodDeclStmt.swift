//
//  ForeignMethodDeclStmt.swift
//
//
//  Created by Garry Pettet on 05/11/2023.
//

import Foundation

public struct ForeignMethodDeclStmt: Stmt {
    /// The name of the class this foreign method belongs to.
    public let className: String
    /// The identifier token for this foreign method.
    public var location: Token
    /// Whether this foreign method is a setter or a regular method.
    public let isSetter: Bool
    /// 'true' if this is a static foreign method declaration.
    public let isStatic: Bool
    /// This foreign method's name.
    public let name: String
    /// This foreign method's parameter identifier tokens.
    public let parameters: [Token]
    /// This foreign method's signature.
    public let signature: String
    
    public init(className: String, identifier: Token, isSetter: Bool, isStatic: Bool, parameters: [Token]) throws {
        self.className = className
        self.location = identifier
        self.name = identifier.lexeme!
        self.isSetter = isSetter
        self.isStatic = isStatic
        self.parameters = parameters
        
        switch identifier.type {
        case .lsquare:
            self.signature = try Objo.computeSubscriptSignature(arity: parameters.count, isSetter: isSetter)
        default:
            self.signature = try Objo.computeSignature(name: name, arity: parameters.count, isSetter: isSetter)
        }
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitForeignMethodDeclaration(stmt: self)
    }
}
