//
// InfixParselet.swift
//
//
// An `InfixParselet` is associated with a token that appears in the middle of the
// expression it parses. Its `parse()` method will be called after the left-hand
// side has been parsed, and it in turn is responsible for parsing everything
// that comes after the token.
//
// This is also used for postfix expressions, in which case it simply doesn't consume
// any more tokens in its `parse()` call.
//
// Created by Garry Pettet on 02/11/2023.

import Foundation

public protocol InfixParselet {
    /// Parses an expression occurring after the provided `left` operand. Assumes the infix token has just been consumed by the parser.
    func parse(parser: Parser, left: Expr, canAssign: Bool) -> Expr
}
