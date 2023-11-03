//
//  MethodInvocationExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct MethodInvocationExpr: Expr {
    /// The arguments to pass to the method call.
    public let arguments: [Expr]
    /// The method identifier in the original token stream.
    public var location: Token
    /// The name of the method to invoke.
    public let methodName: String
    /// The operand the method belongs to. Should evaulate at runtime to an instance or a class.
    public let operand: Expr
    /// The signature of the method to invoke.
    public let signature: String
    
    public init(operand: Expr, identifier: Token, arguments: [Expr], isSetter: Bool) throws {
        self.arguments = arguments
        self.operand = operand
        self.location = identifier
        self.methodName = identifier.lexeme!
        self.signature = try Objo.computeSignature(name: methodName, arity: arguments.count, isSetter: isSetter)
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitMethodInvocation(expr: self)
    }
}
