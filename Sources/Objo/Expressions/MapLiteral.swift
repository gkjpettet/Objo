//
//  MapLiteral.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct MapLiteral: Expr {
    /// Any key-values provided in the map literal's declaration.
    public let keyValues: [KeyValueExpr]
    /// The opening curly brace token.
    public var location: Token
    
    public init(lcurly: Token, keyValues: [KeyValueExpr]) {
        self.location = lcurly
        self.keyValues = keyValues
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitMapLiteral(expr: self)
    }
}
