//
//  LogicalParselet.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct LogicalParselet: InfixParselet {
    /// The precedence of the logical operator to parse.
    private let precedence: Parser.Precedence
    
    public init(precedence: Parser.Precedence) {
        self.precedence = precedence
    }
    
    /// Parses a binary logical operator (or, and, xor).
    /// Assumes the parser has just consumed the operator token.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        // Get the logical operator.
        let op = parser.previous()!
        
        // Parse the right hand operand.
        let right = try parser.parsePrecedence(precedence)
        
        return LogicalExpr(left: left, op: op, right: right)
    }
}
