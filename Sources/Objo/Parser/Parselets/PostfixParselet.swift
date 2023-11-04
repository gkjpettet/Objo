//
//  PostfixParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct PostfixParselet: InfixParselet {
    /// Parses a generic unary postfix expression.
    /// Assumes the parser has just consumed the operator token.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        return PostfixExpr(operand: left, op: parser.previous()!)
    }
}
