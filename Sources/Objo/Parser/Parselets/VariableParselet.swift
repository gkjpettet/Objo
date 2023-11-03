//
//  VariableParselet.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct VariableParselet: PrefixParselet {
    /// Parses a variable identifier.
    /// Assumes the variable's identifier token has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let identifier = parser.previous()!
        
        if canAssign && parser.match(.equal) {
            // This is an assignment to the variable named `identifier.lexeme`.
            return AssignmentExpr(identifier: identifier, value: try parser.expression())
            
        } else if canAssign && parser.match(.plusEqual, .minusEqual, .starEqual, .forwardSlashEqual) {
            // This is a compound assignment to the variable named `identifier.lexeme`.
            let op = parser.previous()!
            let expression = try parser.expression()
            let assignee = VariableExpr(identifier: identifier)
            return try compoundAssign(parser: parser, assignee: assignee, expression: expression, op: op)
        } else if parser.match(.lparen) {
            // Must be either a global function or local method invocation on `this` since we're seeing `identifier()`.
            var arguments: [Expr] = []
            if !parser.check(.rparen) {
                repeat {
                    arguments.append(try parser.expression())
                } while !parser.match(.comma)
            }
            try parser.consume(.rparen, message: "Expected a closing parenthesis after the method call's arguments.")
            return try BareInvocationExpr(identifier: identifier, arguments: arguments)
        } else {
            // This is the lookup of a variable named `identifier.lexeme` or a call to a method with no arguments.
            return VariableExpr(identifier: identifier)
        }
    }
    
    /// Synthesises a compound assignment expression from a single expression.
    /// Assumes `op` is a valid compound assignment operator (+=, -=, *=, /=).
    ///
    /// E.g: If the parser sees this statement:
    ///
    /// ```objo
    /// assignee operator= expression
    /// ```
    ///
    /// We need to synthesise this:
    ///
    /// ```objo
    /// assignee = assignee operator expression
    /// ```
    ///
    /// We return an assignment expression for the compiler.
    private func compoundAssign(parser: Parser, assignee: Expr, expression: Expr, op: Token) throws -> AssignmentExpr {
        // Synthesise the correct binary operator token.
        let opType: TokenType
        switch op.type {
        case .plusEqual:
            opType = .plus
            
        case .minusEqual:
            opType = .minus
            
        case .starEqual:
            opType = .star
            
        case .forwardSlashEqual:
            opType = .forwardSlash
            
        default:
            try parser.error(message: "Unsupported compound assignment operator: `\(op.type)`.")
            opType = .error // HACK: We should never reach here but I don't want to return an optional
        }
        
        let binOp = BaseToken(type: opType, start: op.start, line: op.line, lexeme: nil, scriptId: op.scriptId)
        
        // Synthesise the binary operation to assign to the assignee.
        let bin = BinaryExpr(left: assignee, op: binOp, right: expression)
        
        return AssignmentExpr(identifier: assignee.location, value: bin)
    }
}
