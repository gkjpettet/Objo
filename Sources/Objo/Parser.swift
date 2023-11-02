//
//  Parser.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public class Parser {
    // MARK: - Properties
    
    /// The abstract syntax tree being constructed by the parser.
    private var _ast: [Stmt] = []
    /// The token currently being evaluated.
    private var _current: Token?
    /// The index in `_tokens` of the token currently being processed.
    private var _currentIndex: Int = -1
    /// The previously evaluated token (will be `nil` when the parser begins).
    private var _previous: Token?
    /// The array of tokens that this parser will process.
    private var _tokens: [Token] = []
    
    // MARK: - Public methods
    
    /// Parses an array of tokens into an abstract syntax tree.
    public func parse(tokens: [Token]) throws -> [Stmt] {
        reset()

        _tokens = tokens

        // Prime the pump to get the first token.
        advance()

        while !atEnd() {
            do {
                _ast.append(try declaration())

                // Superfluous eol token?
                _ = match(.endOfLine)
            } catch let error as ParserError {
                panic(error)
            }
        }

        return _ast
    }
    
    public func reset() {
        _ast = []
        _current = nil
        _currentIndex = -1
        _previous = nil
        _tokens = []
    }
    
    // MARK: - Private methods
    
    /// Advances to the next token, storing a reference to the previous token in `_previous`.
    private func advance() {
        _previous = _current
        _currentIndex += 1
        _current = _tokens[_currentIndex]
    }
    
    /// returns `true` if we've reached the end of the token stream.
    private func atEnd() -> Bool {
        return _currentIndex >= _tokens.count || _current?.type == .eof
    }
    
    /// Returns `true` if the current token matches the specified type.
    /// Similar to `match()` but does **not** consume the current token if there is a match.
    private func check(_ type: TokenType) -> Bool {
        if _current?.type == type { return true }
        return false
    }

    /// Returns `true` if the current token matches any of the specified types.
    /// Similar to `match()` but does **not** consume the current token if there is a match.
    private func check(_ types: TokenType...) -> Bool {
        for type in types {
            if _current?.type == type { return true }
        }
        return false
    }
    
    /// Parses a declaration into a `Stmt`.
    ///
    /// An Objo program is a series of statements. Statements produce a side effect.
    /// Declarations are a type of statement that bind new identifiers.
    private func declaration() throws -> Stmt {
        // Edge case: Make sure we skip a superfluous new line that may be present.
        _ = match(.endOfLine)
        
        // TODO
    }

    /// If the current token matches any of the specified types it is consumed and
    /// the function returns `true`. Otherwise it just returns `false`.
    private func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    private func panic(_ error: ParserError) {
        // TODO
    }
}
