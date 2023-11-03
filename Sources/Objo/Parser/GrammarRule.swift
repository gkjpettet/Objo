//
//  GrammarRule.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public struct GrammarRule {
    /// The parselet to use for an infix expression whose left operand is followed by this rule's token.
    public let infix: InfixParselet?
    /// The precedence of an infix expression that uses this rule's token as an operator.
    public let precedence: Parser.Precedence
    /// The parselet to use for a prefix expression starting with this rule's token.
    public let prefix: PrefixParselet?
    
    public init(prefix: PrefixParselet?, infix: InfixParselet?, precedence: Parser.Precedence) {
        self.prefix = prefix
        self.infix = infix
        self.precedence = precedence
    }
}
