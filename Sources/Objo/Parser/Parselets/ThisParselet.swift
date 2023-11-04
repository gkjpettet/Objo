//
//  ThisParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct ThisParselet: PrefixParselet {
    /// Parses `this` (a lookup of the implicit `this` variable).
    /// Assumes the parser has just consumed the `this` token.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        return ThisExpr(thisKeyword: parser.previous()!)
    }
}
