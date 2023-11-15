//
//  MapParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct MapParselet: PrefixParselet {
    /// Parses a map literal.
    /// Assumes a `{` has just been consumed by the parser.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let lcurly = parser.previous()!
        
        // Parse the optional key-values.
        var keyValues: [KeyValueExpr] = []
        if !parser.check(.rcurly) {
            repeat {
                let kv = try parser.expression()
                if !(kv is KeyValueExpr) {
                    try parser.error(message: "Expected a key-value pair.")
                } else {
                    keyValues.append(kv as! KeyValueExpr)
                }
            } while parser.match(.comma)
        }
        
        // Permit an optional newline before the closing curly brace.
        parser.ditch(.endOfLine)
        
        try parser.consume(.rcurly, message: "Expected a closing curly brace after the Map's key-values.")
        
        return MapLiteral(lcurly: lcurly, keyValues: keyValues)
    }
}
