//
//  StaticFieldExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct StaticFieldExpr: Expr {
    /// The static field identifier token itself.
    public var location: Token
    /// The static field's name.
    public var name: String { return location.lexeme! }
    
    public init(identifier: Token) {
        self.location = identifier
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitStaticField(expr: self)
    }
}
