//
//  BareInvocationExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct BareInvocationExpr: Expr {
    /// The arguments to pass to the method call.
    public let arguments: [Expr]
    /// The identifier of the method to invoke (i.e. its name).
    public var location: Token
    /// The name of the method to invoke.
    public var methodName: String { return location.lexeme! }
    /// The signature of the method to invoke.
    public let signature: String
    
    public init(identifier: Token, arguments: [Expr]) throws {
        self.arguments = arguments
        self.location = identifier
        self.signature = try Objo.computeSignature(name: identifier.lexeme!, arity: arguments.count, isSetter: false)
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitBareInvocation(expr: self)
    }
}
