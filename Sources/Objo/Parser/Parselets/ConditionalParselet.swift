//
//  ConditionalParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ConditionalParselet: InfixParselet {
    /// Parses a conditional expression.
    /// Assumes the parser has just consumed the `if` operator.
    ///
    /// ```
    /// thenBranch if condition else elseBranch
    /// ```
    ///
    /// The precedences used here are taken from the Wren compiler because Bob Nystrom is smarter than I am:
    /// https://github.com/wren-lang/wren/blob/main/src/vm/wren_compiler.c
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let ifKeyword = parser.previous()!
        
        // Parse the condition branch.
        let condition = try parser.parsePrecedence(.conditional)
        
        try parser.consume(.else_, message: "Expected the `else` keyword keyword after the condition.")
        
        // Parse the "else" branch.
        // I thought this should have an `assignment` precedence but during testing it would seem
        // `lowest` is required. This *might* be wrong though...
        let elseBranch = try parser.parsePrecedence(.lowest)
        
        return TernaryExpr(condition: condition, thenBranch: left, elseBranch: elseBranch, ifKeyword: ifKeyword)
    }
}
