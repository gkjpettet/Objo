//
//  SuperParselet.swift
//
//
//  Created by Garry Pettet on 04/11/2023.
//

import Foundation

public struct SuperParselet: PrefixParselet {
    /// Parses a `super` expression.
    /// Assumes the `super` token has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let superKeyword = parser.previous()!
        
        if parser.match(.lparen) {
            // A bare invocation on `super` (e.g: `super(argN)`).
            return try parseBareSuper(parser: parser, superKeyword: superKeyword, consumedLParen: canAssign)
            
        } else if parser.match(.dot) {
            // Must be a super method call (e.g: `super.something()` or `super.setter = something`).
            return try parseSuperMethodCall(parser: parser, superKeyword: superKeyword, canAssign: canAssign)
            
        } else {
            // `super` on its own.
            return try parseBareSuper(parser: parser, superKeyword: superKeyword, consumedLParen: false)
        }
    }
    
    /// Parses a bare invocation on `super`.
    ///
    /// E.g: `super(argN)` or `super`
    private func parseBareSuper(parser: Parser, superKeyword: Token, consumedLParen: Bool) throws -> BareSuperInvocationExpr {
        // Optional arguments.
        var arguments: [Expr] = []
        if consumedLParen {
            if !parser.check(.rparen) {
                repeat {
                    arguments.append(try parser.expression())
                } while parser.match(.comma)
            }
            try parser.consume(.rparen, message: "Expected a closing parenthesis after the super constructor's arguments.")
        }
        
        return BareSuperInvocationExpr(superKeyword: superKeyword, arguments: arguments, hasParentheses: consumedLParen)
    }
    
    /// Parses a super method call.
    /// Assumes the `.` after `super` has just been consumed.
    ///
    /// E.g: `super.identifier(argN)` or `super.identifier = something`
    private func parseSuperMethodCall(parser: Parser, superKeyword: Token, canAssign: Bool) throws -> Expr {
        // Get the method to invoke on `super`.
        let methodIdentifier = try parser.fetch(.identifier, message: "Expected a method name after the dot.")
        
        // This may be a setter call so parse the value to assign if the precedence allows.
        var valueToAssign: Expr?
        var arguments: [Expr] = []
        var isMethodInvocation = false
        
        if canAssign && parser.match(.equal) {
            valueToAssign = try parser.expression()
        } else if parser.match(.lparen) {
            // This is an immediate method invocation on `super` since we're seeing: `super.identifier(`
            isMethodInvocation = true
            if !parser.check(.rparen) {
                repeat {
                    arguments.append(try parser.expression())
                } while parser.match(.comma)
            }
            try parser.consume(.rparen, message: "Expected a closing parenthesis after the method call's arguments.")
        } else {
            // This is an immediate method invocation on `super` with zero arguments: "super.identifier"
            isMethodInvocation = true
        }
        
        if isMethodInvocation {
            return try SuperMethodInvocationExpr(superKeyword: superKeyword, methodIdentifier: methodIdentifier, arguments: arguments)
        } else {
            return try SuperSetterExpr(superKeyword: superKeyword, methodIdentifier: methodIdentifier, valueToAssign: valueToAssign!)
        }
    }
}
