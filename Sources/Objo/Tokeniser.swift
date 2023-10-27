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
    /// The previously consumed character.
    private var _previousCharacter: Character? = nil
    /// The id of the script current being processed.
    private var _scriptId: Int = -1
    /// The source currently being processed.
    private var _source: String = ""
    /// The tokens to return.
    private var _tokens: [Token] = []
    /// The 0-based index in `_chars` that the current token starts at.
    private var _tokenStart: Int = 0
    
    // MARK: - Public methods
    
    public init() {}
    
    // MARK: - Private methods

    // TODO: Implement
    private func addBinaryLiteral() -> Bool {
        
    }
    
    // TODO: Implement
    private func addHexLiteral() -> Bool {
        
    }
    
    /// Consumes and adds a number token starting at `_current`.
    ///
    /// Assumes that we've just consumed the first (and possibly only) digit:
    ///
    /// ```
    /// 100
    ///  ^
    /// ```
    /// Note: We allow the use of `_` as a digit separator.
    private func addNumber() throws {
        var char: Character
        var lexeme: [Character] = []
        
        while !atEnd() && peek().isDigitOrUnderscore() {
            char = advance()
            if char != "_" { lexeme.append(char) }
        }
        
        // Edge case 1: Prohibit a trailing underscore.
        if previous() == "_" {
            throw error(type: .unexpectedCharacter, message: "Underscores can separate digits within a number but a number cannot end with one.")
        }
        
        // Is this a double or a whole number?
        var isInt = false
        if peek() == "." && peek(distance: 1).isNumber {
            isInt = false
            
            // Consume the dot.
            lexeme.append(advance())
            
            while peek().isDigitOrUnderscore() {
                char = advance()
                if char != "_" { lexeme.append(char) }
            }
            
            // Edge case 2: Prohibit a trailing underscore within a double.
            if previous() == "_" {
                throw error(type: .unexpectedCharacter, message: "Underscores can separate digits within a number but a number cannot end with one.")
            }
            
            // Is there an exponent?
            if peek() == "e" || peek() == "E" {
                var seenExponentDigit = false
                var nextChar = peek(distance: 1)
                if nextChar == "-" || nextChar == "+" {
                    if nextChar == "-" { isInt = false }
                    // Advance twice to consume the e/E and sign character.
                    lexeme.append(advance())
                    lexeme.append(advance())
                    while peek().isNumber {
                        lexeme.append(advance())
                        seenExponentDigit = true
                    }
                } else if nextChar.isNumber {
                    // Consume the e/E character.
                    lexeme.append(advance())

                    while peek().isNumber {
                        lexeme.append(advance())
                        seenExponentDigit = true
                    }
                }
                
                if !seenExponentDigit {
                    throw error(type: .syntaxError, message: "Unterminated scientific notation.")
                }
            }
        }
        
        // TODO: Finish - need to actually add the token.
        // Needs to be a number token which probably means we need an interface??
    }
    
    /// Adds `token` to the internal `_tokens` array.
    /// Handles end of line tokens.
    private func addToken(_ token: Token) {
        if token.type == .endOfLine {
            if _tokens.isEmpty {
                // Prevent the first token from being an eol.
                return
            } else if _tokens.last?.type == .endOfLine {
                // Prevent contiguous end of line tokens.
                return
            } else {
                // We can add this end of line token.
                _tokens.append(token)
                return
            }
        }
        
        // Add this token.
        _tokens.append(token)
    }
    
    /// Consumes and returns the current character.
    private func advance() -> Character {
        _current += 1
        return _chars[_current - 1]
    }
    
    /// Returns `true` if the tokeniser has reached the end of the source code.
    private func atEnd() -> Bool {
        return _current >= _chars.count
    }
    
    /// Consumes all characters until the end of the line or eof.
    /// Does *not* consume the eol if one is reached.
    /// Comments begin with `#`.
    ///
    /// Assumes we're at the beginning of a comment (i.e. have just consumed the `#`).
    private func consumeComment() {
        while true {
            if peek() == "\0" {
                addToken(makeToken(type: .endOfLine, hasLexeme: false))
                break
            } else if atEnd() {
                break
            } else {
                _ = advance()
            }
        }
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
    
    /// Returns `_chars(_current + distance)` but doesn't consume it.
    /// If we've reached the end it returns the null character (\0)
    private func peek(distance: Int = 0) -> Character {
        return _current + distance < _chars.count ? _chars[_current + distance] : "\0"
    }
    
    /// Advances through `_chars` from the current character and adds the next token to `_tokens`.
    private func nextToken() throws {
        // Track where in _chars this token begins.
        _tokenStart = _current
        
        skipWhitespace()
        
        // Have we reached the end of the source code?
        if atEnd() {
            addToken(makeToken(type: .endOfLine, hasLexeme: false))
            addToken(makeToken(type: .eof, hasLexeme: false))
            return
        }
        
        // Get the character to evaluate.
        let c = advance()
        
        // ====================================================================
        // Numbers.
        // ====================================================================
        if c.isNumber {
            if c == "0" && peek() == "x" {
                // Maybe hex literal (e.g. 0xFF).
                if addHexLiteral() { return }
            } else if c == "0" && peek() == "b" {
                // Maybe binary literal (e.g. 0b10).
                if addBinaryLiteral() { return }
            } else {
                addNumber()
                return
            }
        }
        
        throw error(type: .unexpectedCharacter, message: "Unexpected character.")
    }
    
    /// Returns the previously consumed character or nil if this is the first character.
    private func previous() -> Character? {
        if _current - 1 >= 0 {
            return _chars[_current - 1]
        } else {
            return nil
        }
    }
    
    /// Resets the tokeniser's internal properties, ready to tokenise again.
    public func reset() {
        _chars = []
        _current = 0
        _lineNumber = 1
        _previousCharacter = nil
        _scriptId = -1
        _source = ""
        _tokenStart = 0
        _tokens = []
    }
    
    /// Advances past whitespace.
    ///
    /// Updates `_tokenStart` if needed.
    /// Handles newlines following an underscore token.
    private func skipWhitespace() {
    whileLoop: while true {
            switch peek() {
            case "\0":
                break whileLoop
                
            case " ", "\t":
                _ = advance()
                
            case "#": // Comment.
                consumeComment()
                
            case "\n":
                let lastTokenType = _tokens.last?.type
                
                // Was the last token an underscore? If so, we remove the underscore
                // token and omit adding an eol token. To the parser, this will
                // appear as though the tokens before the underscore token and those
                // following this newline are on the same line.
                switch lastTokenType {
                case .underscore:
                    _ = _tokens.popLast()
                    _ =  advance()
                    _lineNumber += 1
                    
                case .comma, .lcurly, .lsquare:
                    // Omit adding an eol token. To the parser, this will appear as though the
                    // tokens before this and those following this new line are on the same line.
                    // This allows us to split map and list literals over multiple lines.
                    _ = advance()
                    _lineNumber += 1
                    
                default:
                    addToken(makeToken(type: .endOfLine, hasLexeme: false))
                    _ = advance()
                    _lineNumber += 1
                }
                
            default:
                break whileLoop
            }
        }
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
        
        // Tokenise.
        repeat {
            try nextToken()
        } while !atEnd()
        
        // Remove the EOF token if requested.
        if !includeEOF { _ = _tokens.popLast() }
            
        // Since struct arrays are a value type we can return the internal Token array
        // and it should be copied.
        return _tokens
    }
}
