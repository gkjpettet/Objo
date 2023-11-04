//
//  GroupParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct GroupParselet: PrefixParselet {
    /// Parses the parentheses used to group an expression. Returns the expression within the parentheses.
    /// Assumes the `(` has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let expression = try parser.expression()
        
        try parser.consume(.rparen, message: "Expected a closing parenthesis after grouped expression.")
        
        return expression
    }
}
