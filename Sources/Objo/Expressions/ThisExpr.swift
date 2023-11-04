//
//  ThisExpr.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ThisExpr: Expr {
    /// The `this` token.
    public var location: Token
    
    public init(thisKeyword: Token) {
        self.location = thisKeyword
    }
    
    public func accept(_ visitor: ExprVisitor) {
        visitor.visitThis(expr: self)
    }
}
