//
//  KeyValueParselet.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

/// Parses a key-value pair.
/// Assumes the parser has just consumed the `:` token.
public struct KeyValueParselet: InfixParselet {
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let colon = parser.previous()!
        
        let right = try parser.expression()
        
        return KeyValueExpr(colon: colon, key: Expr, value: Expr)
    }
}
