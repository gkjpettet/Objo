//
//  VariableExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct VariableExpr: Expr {
    /// The variable identifier token itself.
    public var location: Token
    /// The variable's name.
    public var name: String { return location.lexeme! }
    
    public init(identifier: Token) {
        self.location = identifier
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitVariable(expr: self)
    }
}
