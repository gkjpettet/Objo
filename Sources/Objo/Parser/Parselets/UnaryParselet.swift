//
//  UnaryParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct UnaryParselet: PrefixParselet {
    /// Parses a generic unary operator.
    /// Assumes the operator has just been consumed by the parser.
    ///
    /// Parses prefix unary `-`, `~` and `not` expressions.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        // Get the operator token.
        let op = parser.previous()!
        
        // Parse the operand.
        let right = try parser.parsePrecedence(.unary)
        
        return UnaryExpr(op: op, operand: right)
    }
}
