//
//  ClassParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ClassParselet: PrefixParselet {
    /// Parses a class identifier (these begin with an uppercase letter).
    /// Assumes the class's identifier token has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let identifier = parser.previous()!
        
        // This is the lookup of a class named `identifier.lexeme`.
        return ClassExpr(identifier: identifier)
    }
}
