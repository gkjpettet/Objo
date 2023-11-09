//
//  FieldAssignmentExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct FieldAssignmentExpr: Expr {
    /// The field's identifier token.
    public var location: Token
    /// The name of the field to assign to.
    public var name: String { return location.lexeme! }
    /// The expression to assign to this field.
    public let value: Expr
    
    public init(identifier: Token, value: Expr) {
        self.location = identifier
        self.value = value
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitFieldAssignment(expr: self)
    }
}
