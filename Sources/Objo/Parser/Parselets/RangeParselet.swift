//
//  File.swift
//  
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct RangeParselet: InfixParselet {
    /// Parses a range operator.
    /// Assumes the parser has just consumed the range operator token.
    public func parse(parser: Parser, left: Expr, canAssign: Bool) throws -> Expr {
        let op = parser.previous()!
        
        let right = try parser.parsePrecedence(.range)
        
        return RangeExpr(lower: left, op: op, upper: right)
    }
}
