//
//  SuperSetterExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SuperSetterExpr: Expr {
    /// The identifier after the dot.
    public let identifier: Token
    /// The `super` token itself.
    public var location: Token
    /// The signature of the setter to invoke.
    public let signature: String
    /// The value to assign.
    public let valueToAssign: Expr
    
    public init(superKeyword: Token, methodIdentifier: Token, valueToAssign: Expr) throws {
        self.location = superKeyword
        self.identifier = methodIdentifier
        self.valueToAssign = valueToAssign
        self.signature = try Objo.computeSignature(name: methodIdentifier.lexeme!, arity: 1, isSetter: true)
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitSuperSetter(expr: self)
    }
}
