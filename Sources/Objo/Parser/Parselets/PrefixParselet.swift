//
// PrefixParselet.swift
//
//
// A PrefixParselet is associated with a token that appears at the beginning of an expression.
// Its `parse()` method will be called with the consumed leading token, and the
// parselet is responsible for parsing anything that comes after that token.
//
// Created by Garry Pettet on 02/11/2023.

import Foundation

public protocol PrefixParselet {
    /// Parses a prefix expression. Assumes the prefix token has just been consumed by the `parser` when this method is called.
    func parse(parser: Parser, canAssign: Bool) throws -> Expr
}
