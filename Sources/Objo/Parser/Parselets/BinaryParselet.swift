//
//  BinaryParselet.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct BinaryParselet: InfixParselet {
    private let precedence: Parser.Precedence
    public let rightAssociative: Bool
    
    public init(precedence: Parser.Precedence, rightAssociative: Bool) {
        self.precedence = precedence
        self.rightAssociative = rightAssociative
    }
    
    /// Parses a binary operator.
    /// Assumes the parser has just consumed the operator token.
    ///
    /// The only difference when parsing, `+`, `-`, `*`, `/`, and `^` is precedence and
    /// associativity, so we can use a single parselet class for all of those.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        // Grab the operator from the parser.
        let op: Token = parser.previous()!
        
        // To handle right-associative operators like `^`, we allow a slightly
        // lower precedence when parsing the right-hand side. This will let a
        // parselet with the same precedence appear on the right, which will then
        // take *this* parselet's result as its left-hand argument.
        if rightAssociative {
            let right = try parser.parsePrecedence(Parser.Precedence(rawValue: precedence.rawValue - 1)!)
            return BinaryExpr(left: left, op: op, right: right)
        } else {
            return BinaryExpr(left: left, op: op, right: try parser.parsePrecedence(precedence))
        }
    }
}
