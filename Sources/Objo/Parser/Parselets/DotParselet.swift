//
//  DotParselet.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct DotParselet: InfixParselet {
    /// Parses the dot operator.
    /// Assumes the parser has just consumed the dot.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        // Get the name of the method to invoke.
        let identifier = try parser.fetch(.identifier, message: "Expected a method name after the dot.")
        
        // This may be a setter call so parse the value to assign if the precedence allows.
        // The value to assign then becomes the argument.
        var arguments: [Expr] = []
        var isSetter = false

        if canAssign && parser.match(.equal) {
            isSetter = true
            arguments.append(try parser.expression())
        } else if parser.match(.lparen) {
            if !parser.check(.rparen) {
                repeat {
                    arguments.append(try parser.expression())
                } while !parser.match(.comma)
            }
            try parser.consume(.rparen, message: "Expected a closing parenthesis after the method call's arguments.")
        }
        
        return try MethodInvocationExpr(operand: left, identifier: identifier, arguments: arguments, isSetter: isSetter)
    }
}
