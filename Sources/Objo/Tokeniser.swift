//
//  File.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public class Tokeniser {

    // MARK: - Properties
    
    /// The individual characters of the source currently being processed.
    private var _chars: [Character] = []
    /// The 0-based index in `_chars` where the tokeniser currently is.
    private var _current: Int = 0
    /// The 1-based number of the line currently being processed.
    private var _lineNumber: Int = 1
    /// The id of the script current being processed.
    private var _scriptId: Int = -1
    /// The source currently being processed.
    private var _source: String = ""
    /// The 0-based index in `_chars` that the current token starts at.
    private var _tokenStart: Int = 0
    
    // MARK: - Public methods
    
    public init() {}
    
    // MARK: - Private methods

    /// Returns `true` if the tokeniser has reached the end of the source code.
    private func atEnd() -> Bool {
        return _current >= _chars.count
    }
    
    /// Returns a lexer error of the specified type at the current position.
    private func error(type: LexerError.ErrorType, message: String) -> LexerError {
        return LexerError(line: _lineNumber, message: message, scriptId: _scriptId, start: _tokenStart, type: type)
    }
    
    /// A convenience function for returning an end of file token.
    private func makeEofToken() -> Token {
        return Token(type: .eof, start: _chars.count, line: _lineNumber, lexeme: nil, scriptId: _scriptId)
    }
    
    /// Returns a token of the specified type beginning at _tokenStart on the current line in the current script.
    private func makeToken(type: TokenType, hasLexeme: Bool) -> Token {
        if hasLexeme {
            let lexeme = String(_chars[_tokenStart..._current])
            return Token(type: type, start: _tokenStart, line: _lineNumber, lexeme: lexeme, scriptId: _scriptId)
        } else {
            return Token(type: type, start: _tokenStart, line: _lineNumber, lexeme: nil, scriptId: _scriptId)
        }
    }
    
    /// Advances through `_chars` from the current character to construct and return the next token.
    private func nextToken() throws -> Token {
        // Track where in _chars this token begins.
        _tokenStart = _current
        
        skipWhitespace()
        
        // Have we reached the end of the source code?
        if atEnd() {
            return makeToken(type: .endOfLine, hasLexeme: false)
        }
        
        throw error(type: .unexpectedCharacter, message: "Unexpected character.")
    }
    
    /// Resets the tokeniser's internal properties, ready to tokenise again.
    public func reset() {
        _chars = []
        _current = 0
        _lineNumber = 1
        _scriptId = -1
        _source = ""
        _tokenStart = 0
    }
    
    // TODO: Implement
    private func skipWhitespace() {
        
    }
    
    /// Tokenises Objo source code into an array of tokens.
    ///
    /// - Parameters:
    ///   - source: The unprocessed source code to process.
    ///   - scriptId: An integer representing the script file the source code originated in.
    ///   - includeEOF: By default the tokeniser appends an EOF token when its finished. This can optionally
    ///   be omitted. Useful if several files are being tokeninsed and concatenated together.
    public func tokenise(source: String, scriptId: Int, includeEOF: Bool = true) throws -> [Token] {
        reset()
        
        _scriptId = scriptId
        
        // Keep a reference to the source code.
        _source = source
        
        // Split the source into characters.
        _chars = Array(_source)
        
        // Create an empty Token array we can return to the caller.
        var tokens: [Token] = []
        
        // Tokenise.
        repeat {
            // Get the next token.
            let token = try nextToken()
            
            // We need to handle end of lines differently than other tokens.
            if token.type == .endOfLine {
             // Prevent the first token from being an eol.
                if tokens.isEmpty {
                    continue
                } else if tokens.last?.type == .endOfLine {
                    // Prevent contiguous end of line tokens.
                    continue
                } else {
                    // We can add this end of line token.
                    tokens.append(token)
                    continue
                }
            }
            
            // All other tokens
            tokens.append(token)
        } while !atEnd()
        
        if includeEOF { tokens.append(makeEofToken()) }
            
        return tokens
    }
}
