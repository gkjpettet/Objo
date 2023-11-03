//
//  LiteralParselet.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct LiteralParselet: PrefixParselet {
    /// Parses a literal (e.g. number, boolean, etc).
    /// Assumes the literal's token has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let literal = parser.previous()!
        
        switch literal.type {
        case .number:
            return NumberLiteral(token: literal as! NumberToken)
            
        case .boolean:
            return BooleanLiteral(token: literal as! BooleanToken)
            
        case .nothing:
            return NothingLiteral(token: literal)
            
        case .string:
            return StringLiteral(token: literal)
            
        default:
            throw ParserError(message: "Unexpected literal type.", location: literal)
        }
    }
}
