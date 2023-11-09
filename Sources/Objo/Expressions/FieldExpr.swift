//
//  FieldExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct FieldExpr: Expr {
    /// The field identifier token itself.
    public var location: Token
    /// The field's name.
    public var name: String { return location.lexeme! }
    
    public init(identifier: Token) {
        self.location = identifier
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
       try visitor.visitField(expr: self)
    }
}
