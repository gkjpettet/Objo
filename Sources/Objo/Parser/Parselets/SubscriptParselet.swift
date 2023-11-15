//
//  SubscriptParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SubscriptParselet: InfixParselet {
    /// Parses a subscript expression.
    /// Assumes the parser has just consumed the `[` token.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let lsquare = parser.previous()!
        
        // Parse the index(es).
        var indexes: [Expr] = []
        if !parser.check(.rsquare) {
            repeat {
                indexes.append(try parser.expression())
            } while parser.match(.comma)
        }
        
        try parser.consume(.rsquare, message: "Expected a closing square brace after the indexes.")
        
        // There must be at least one index.
        if indexes.count < 1 {
            try parser.error(message: "At least one subscript index is required.")
        }
        
        // This may be a subscript setter so parse the value to assign if the precedence allows.
        if canAssign && parser.match(.equal) {
            return try SubscriptSetterExpr(lsquare: lsquare, operand: left, indexes: indexes, valueToAssign: try parser.expression())
        } else {
            return try SubscriptExpr(lsquare: lsquare, operand: left, indexes: indexes)
        }
    }
}
