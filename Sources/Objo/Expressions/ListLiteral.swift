//
//  ListLiteral.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ListLiteral: Expr {
    /// The initial elements.
    public let elements: [Expr]
    /// The opening square bracket token.
    public var location: Token
    
    public init(lsquare: Token, elements: [Expr]) {
        self.location = lsquare
        self.elements = elements
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitListLiteral(expr: self)
    }
}
