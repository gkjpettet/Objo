//
//  AssignmentExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct AssignmentExpr: Expr {
    /// The variable's identifier token.
    public var location: Token
    /// The name of the variable to assign to.
    public var name: String { return location.lexeme! }
    /// The expression to assign to this variable.
    public let value: Expr
    
    public init(identifier: Token, value: Expr) {
        self.location = identifier
        self.value = value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        return try visitor.visitAssignment(expr: self)
    }
}
