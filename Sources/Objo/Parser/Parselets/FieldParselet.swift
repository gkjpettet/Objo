//
//  FieldParselet.swift
//
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public struct FieldParselet: PrefixParselet {
    /// Parses a field identifier. Either a field access or a field assignment.
    /// Assumes the field identifier token has just been consumed by the `parser`.
    public func parse(parser: Parser, canAssign: Bool) throws -> Expr {
        let identifier = parser.previous()!
        let isStatic = identifier.type == .staticFieldIdentifier ? true : false
        
        if canAssign && parser.match(.equal) {
            
            // This is an assignment to the field named `identifier.lexeme`.
            if isStatic {
                return StaticFieldAssignmentExpr(identifier: identifier, value: try parser.expression())
            } else {
                return FieldAssignmentExpr(identifier: identifier, value: try parser.expression())
            }
            
        } else if canAssign && parser.match(.plusEqual, .minusEqual, .starEqual, .forwardSlashEqual) {
            
            let op = parser.previous()!
            
            // This is a compound assignment to the field named `identifier.lexeme`.
            let expression = try parser.expression()
            if isStatic {
                return try compoundAssign(parser: parser, assignee: StaticFieldExpr(identifier: identifier), expression: expression, op: op, isStatic: true)
            } else {
                return try compoundAssign(parser: parser, assignee: FieldExpr(identifier: identifier), expression: expression, op: op, isStatic: false)
            }
            
        } else {
            
            // This is a lookup of the field named `identifier.Lexeme`.
            if isStatic {
                return StaticFieldExpr(identifier: identifier)
            } else {
                return FieldExpr(identifier: identifier)
            }
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
    /// We return either a static or instance field assignment expression for the compiler.
    private func compoundAssign(parser: Parser, assignee: Expr, expression: Expr, op: Token, isStatic: Bool) throws -> Expr {
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
            try parser.error(message: "Unsupported field compound assignment operator: `\(op)`.")
            opType = .error // HACK: We should never reach here but I don't want to return an optional
        }
        
        let binOp = BaseToken(type: opType, start: op.start, line: op.line, lexeme: nil, scriptId: op.scriptId)
        
        // Synthesise the binary operation to assign to assignee.
        let bin = BinaryExpr(left: assignee, op: binOp, right: expression)
        
        // Return a new assignment expression.
        if isStatic {
            return StaticFieldAssignmentExpr(identifier: assignee.location, value: bin)
        } else {
            return FieldAssignmentExpr(identifier: assignee.location, value: bin)
        }
    }
}
