//
//  ClassExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ClassExpr: Expr {
    /// The class name identifier token.
    public var location: Token
    /// The class name.
    public var name: String { return location.lexeme! }
    
    public init(identifier: Token) {
        self.location = identifier
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitClass(expr: self)
    }
}
