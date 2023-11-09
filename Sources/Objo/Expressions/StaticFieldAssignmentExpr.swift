//
//  StaticFieldAssignmentExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct StaticFieldAssignmentExpr: Expr {
    /// The static field's identifier token.
    public var location: Token
    /// The name of the static field to assign to.
    public var name: String { return location.lexeme! }
    /// The expression to assign to this static field.
    public let value: Expr
    
    public init(identifier: Token, value: Expr) {
        self.location = identifier
        self.value = value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitStaticFieldAssignment(expr: self)
    }
}
