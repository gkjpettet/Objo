//
//  BinaryExpr.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct BinaryExpr: Expr {
    /// The left hand expression.
    public let left: Expr
    /// The location of the operator token.
    public var location: Token
    /// The operator token.
    public let op: Token
    /// The right hand expression.
    public let right: Expr
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitBinary(expr: self)
    }
    
    public init(left: Expr, op: Token, right: Expr) {
        self.left = left
        self.location = op
        self.op = op
        self.right = right
    }
}
