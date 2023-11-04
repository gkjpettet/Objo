//
//  SuperMethodInvocationExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SuperMethodInvocationExpr: Expr {
    /// The arguments to pass to the method call on `super`. May be empty.
    public let arguments: [Expr]
    /// The identifier of the method to invoke on `super` (i.e. the method's name).
    public var location: Token
    /// The signature of the method to invoke on `super`.
    public let signature: String
    /// The `super` keyword token.
    public let superKeyword: Token
    
    public init(superKeyword: Token, methodIdentifier: Token, arguments: [Expr]) throws {
        self.superKeyword = superKeyword
        self.location = methodIdentifier
        self.arguments = arguments
        self.signature = try Objo.computeSignature(name: methodIdentifier.lexeme!, arity: arguments.count, isSetter: false)
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitSuperMethodInvocation(expr: self)
    }
}
