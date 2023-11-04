//
//  IsParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct IsParselet: InfixParselet {
    /// Parses the `is` operator.
    /// Assumes the parser has just consumed the `is` keyword.
    ///
    /// ```
    /// value is type
    /// ```
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let isKeyword = parser.previous()!
        
        let type = try parser.parsePrecedence(.is_)
        
        return IsExpr(value: left, type: type, isKeyword: isKeyword)
    }
}
