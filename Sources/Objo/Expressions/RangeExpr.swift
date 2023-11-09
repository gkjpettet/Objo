//
//  RangeExpr.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct RangeExpr: Expr {
    /// The range operator token.
    public var location: Token
    /// The lower bounds of the range.
    public let lower: Expr
    /// `true` if this is an inclusive range operation.
    public var isInclusive: Bool { return location.type == .dotDotDot }
    /// The range operator type.
    public var op: TokenType { return location.type }
    /// The upper bounds of the range.
    public let upper: Expr
    
    public init(lower: Expr, op: Token, upper: Expr) {
        self.lower = lower
        self.location = op
        self.upper = upper
    }
    
    public func accept(_ visitor: ExprVisitor) throws {
        try visitor.visitRange(expr: self)
    }
}
