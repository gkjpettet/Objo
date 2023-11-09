//
//  ClassDeclStmt.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ClassDeclStmt: Stmt {
    /// This class's constructor declarations. May be empty.
    public let constructors: [ConstructorDeclStmt]
    /// This class's foreign instance method declarations. Key = signature, value = ForeignMethodDeclStmt.
    public let foreignInstanceMethods: [String : ForeignMethodDeclStmt]
    /// This class's foreign static method declarations. Key = signature, value = ForeignMethodDeclStmt.
    public let foreignStaticMethods: [String : ForeignMethodDeclStmt]
    /// `true` if this class has a superclass.
    public var hasSuperclass: Bool { return superclass != nil }
    /// The class name token.
    public let identifier: Token
    /// `true` if this is a foreign class.
    public let isForeign: Bool
    /// The `class` keyword location.
    public var location: Token
    /// This class's method declarations. Key = signature, Value = MethodDeclStmt.
    public let methods: [String : MethodDeclStmt]
    /// The name of the class to declare.
    public var name: String { return identifier.lexeme! }
    /// This class's static method declarations. Key = signature, value = MethodDeclStmt.
    public let staticMethods: [String : MethodDeclStmt]
    /// The superclass (if any).
    public let superclass: String?
    
    public init(superclass: String?, identifier: Token, constructors: [ConstructorDeclStmt], staticMethods: [String : MethodDeclStmt], methods: [String : MethodDeclStmt], foreignInstanceMethods: [String : ForeignMethodDeclStmt], foreignStaticMethods: [String : ForeignMethodDeclStmt], classKeyword: Token, isForeign: Bool) {
        
        self.superclass = superclass
        self.identifier = identifier
        self.constructors = constructors
        self.staticMethods = staticMethods
        self.methods = methods
        self.foreignInstanceMethods = foreignInstanceMethods
        self.foreignStaticMethods = foreignStaticMethods
        self.location = classKeyword
        self.isForeign = isForeign
        
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitClassDeclaration(stmt: self)
    }
}
