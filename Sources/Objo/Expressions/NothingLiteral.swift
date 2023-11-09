//
//  NothingLiteral.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct NothingLiteral: Expr {
    /// The location of the "nothing" literal or inferred "nothing" value.
    public var location: Token
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitNothing(expr: self)
    }
    
    public init(token: Token) {
        self.location = token
    }
}
