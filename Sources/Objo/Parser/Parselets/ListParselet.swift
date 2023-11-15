//
//  ListParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ListParselet: PrefixParselet {
    /// Parses a list literal.
    /// Assumes a `[` has just been consumed by the parser.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let lsquare = parser.previous()!
        
        // Parse the optional elements.
        var elements: [Expr] = []
        if !parser.check(.rsquare) {
            repeat {
                elements.append(try parser.expression())
            } while parser.match(.comma)
        }
        
        try parser.consume(.rsquare, message: "Expected a closing square bracket after the List's values.")
        
        return ListLiteral(lsquare: lsquare, elements: elements)
    }
}
