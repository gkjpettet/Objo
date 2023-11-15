//
//  CallParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct CallParselet: InfixParselet {
    /// Parses a call expression.
    /// Assumes `parser` has just consumed the `(`.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let lparen = parser.previous()!
        
        var arguments: [Expr] = []
        if !parser.check(.rparen) {
            repeat {
                arguments.append(try parser.expression())
            } while parser.match(.comma)
        }
        
        try parser.consume(.rparen, message: "Expected a closing parenthesis after the call's arguments.")
        
        return CallExpr(callee: left, arguments: arguments, lparen: lparen)
    }
}
