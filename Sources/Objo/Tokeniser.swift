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

    /// Attempts to add a binary literal token beginning at the current position.
    /// Returns `true` if successful.
    ///
    /// Assumes that `_current` points to the "0" character illustrated below **and**
    /// that the next character is definitely a "b":
    /// ```
    /// 0b1100
    ///  ^
    /// ```
    private func addBinaryLiteral() -> Bool {
        // Move past the "b" character.
        eat()
        
        // Me need to see at least one binary digit.
        if !peek().isBinaryDigit() {
            // Rewind a character (since we advanced past the "b").
            _current -= 1
            return false
        } else {
            eat()
        }
        
        // Consume all contiguous binary digits.
        while peek().isBinaryDigit() {
            eat()
        }
        
        // The next character must not be a letter.
        if peek().isLetter {
            // Rewind to the character after the token start position.
            _current = _tokenStart + 1
            return false
        }
        
        // Compute the lexeme (without the "0b" prefix).
        let lexeme = String(_chars[_tokenStart + 2..._current - 1])
        
        // Compute the value as an unsigned integer.
        let value = Int(lexeme, radix: 2)
        
        // Create and add this literal as a number token.
        _tokens.append(NumberToken(value: Double(value!), isInteger: true, start: _tokenStart, line: _lineNumber, lexeme: "0b\(lexeme)", scriptId: _scriptId))
        
        return true
    }
    
    /// Attempts to add a hex literal token beginning at the current position.
    /// Returns `true` if successful.
    ///
    /// Assumes that `_current` points to the "0" character illustrated below **and**
    /// that the next character is definitely an "x":
    /// ```
    /// 0xFFA1
    ///  ^
    /// ```
    private func addHexLiteral() -> Bool {
        // Move past the "x" character.
        eat()
        
        // Me need to see at least one hex digit.
        if !peek().isHexDigit {
            // Rewind a character (since we advanced past the "x").
            _current -= 1
            return false
        } else {
            eat()
        }
        
        // Consume all contiguous hex digits.
        while peek().isHexDigit {
            eat()
        }
        
        // The next character must not be a letter.
        if peek().isLetter {
            // Rewind to the character after the token start position.
            _current = _tokenStart + 1
            return false
        }
        
        // Compute the lexeme (without the "0x" prefix).
        let lexeme = String(_chars[_tokenStart + 2..._current - 1])
        
        // Compute the value as an unsigned integer.
        let value = Int(lexeme, radix: 16)
        
        // Create and add this literal as a number token.
        _tokens.append(NumberToken(value: Double(value!), isInteger: true, start: _tokenStart, line: _lineNumber, lexeme: "0x\(lexeme)", scriptId: _scriptId))
        
        return true
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
        var lexemeChars: [Character] = [previous()!]
        
        // Gather up contiguous digits and underscores. This is the integer component.
        while !atEnd() && peek().isDigitOrUnderscore() {
            let char = advance()
            if char != "_" { lexemeChars.append(char) }
        }
        
        // Edge case: Prohibit a trailing underscore.
        if previous() == "_" {
            throw error(type: .unexpectedCharacter, message: "Underscores can separate digits within a number but a number cannot end with one.")
        }
        
        // Is this a double or an integer? Default to it being an integer.
        var isInteger = true
        if peek() == "." {
            isInteger = false
            
            // Consume the decimal point.
            lexemeChars.append(advance())
            
            // We must see at least one digit.
            if !peek().isDigit() {
                throw error(type: .syntaxError, message: "Expected a digit after the decimal point.")
            }
            
            // Get the fractional component.
            while peek().isDigitOrUnderscore() {
                let char = advance()
                if char != "_" { lexemeChars.append(char) }
            }
            
            // Edge case 2: Prohibit a trailing underscore within a double.
            if previous() == "_" {
                throw error(type: .unexpectedCharacter, message: "Underscores can separate digits within a number but a number cannot end with one.")
            }
        }
        
        // Is there an exponent?
        if peek() == "e" || peek() == "E" {
            var seenExponentDigit = false
            // Number literals with an exponent will be integers unless the exponent is negative.
            isInteger = true
            let nextChar = peek(distance: 1)
            if nextChar == "-" || nextChar == "+" {
                if nextChar == "-" { isInteger = false }
                // Advance twice to consume the e/E and sign character.
                lexemeChars.append(advance())
                lexemeChars.append(advance())
                while peek().isDigit() {
                    lexemeChars.append(advance())
                    seenExponentDigit = true
                }
            } else if nextChar.isDigit() {
                // Consume the e/E character.
                lexemeChars.append(advance())

                while peek().isDigit() {
                    lexemeChars.append(advance())
                    seenExponentDigit = true
                }
            }
            
            if !seenExponentDigit {
                throw error(type: .syntaxError, message: "Unterminated scientific notation.")
            }
        }
        
        // Compute the actual value of the literal.
        let lexeme = String(lexemeChars)
        guard let value = Double(lexeme) else {
            throw error(type: .syntaxError, message: "Invalid number literal: \(lexeme).")
        }
        
        // Add this number token.
        _tokens.append(NumberToken(value: value, isInteger: isInteger, start: _tokenStart, line: _lineNumber, lexeme: lexeme, scriptId: _scriptId))
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
                eat()
            }
        }
    }
    
    /// Consumes the current character.
    private func eat() {
        _current += 1
    }
    
    /// Returns a lexer error of the specified type at the current position.
    private func error(type: LexerError.ErrorType, message: String) -> LexerError {
        return LexerError(line: _lineNumber, message: message, scriptId: _scriptId, start: _tokenStart, type: type)
    }
    
    /// A convenience function for returning an end of file token.
    private func makeEofToken() -> Token {
        return BaseToken(type: .eof, start: _chars.count, line: _lineNumber, lexeme: nil, scriptId: _scriptId)
    }
    
    /// Returns a base token of the specified type beginning at _tokenStart on the current line in the current script.
    private func makeToken(type: TokenType, hasLexeme: Bool) -> BaseToken {
        if hasLexeme {
            let lexeme = String(_chars[_tokenStart..._current])
            return BaseToken(type: type, start: _tokenStart, line: _lineNumber, lexeme: lexeme, scriptId: _scriptId)
        } else {
            return BaseToken(type: type, start: _tokenStart, line: _lineNumber, lexeme: nil, scriptId: _scriptId)
        }
    }
    
    /// If the next character matches `c` then it's consumed and `true` is returned.
    /// Otherwise it leaves the character alone and returns `false`.
    private func match(_ c: Character) -> Bool {
        if peek() == c {
            eat()
            return true
        } else {
            return false
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
                try addNumber()
                return
            }
        }
        
        // ====================================================================
        // Single OR multiple character tokens.
        // `c` is a character that can occur on its own or can occur in
        // combination with one or more characters.
        // ====================================================================
        switch c {
            // TODO: Add the remaining cases.
        case "+":
            if match("=") {
                addToken(makeToken(type: .plusEqual, hasLexeme: true))
                return
            } else if match("+") {
                addToken(makeToken(type: .plusPlus, hasLexeme: true))
                return
            } else {
                addToken(makeToken(type: .plus, hasLexeme: true))
                return
            }
            
        default:
            break
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
    
    /// Returns `true` if the tokeniser has reached the end of the source code.
    private func reachedEOF() -> Bool {
        return _tokens.count > 0 && _tokens.last!.type == .eof
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
                eat()
                
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
                    eat()
                    _lineNumber += 1
                    
                case .comma, .lcurly, .lsquare:
                    // Omit adding an eol token. To the parser, this will appear as though the
                    // tokens before this and those following this new line are on the same line.
                    // This allows us to split map and list literals over multiple lines.
                    eat()
                    _lineNumber += 1
                    
                default:
                    addToken(makeToken(type: .endOfLine, hasLexeme: false))
                    eat()
                    _lineNumber += 1
                }
                
            default:
                break whileLoop
            }
        }
        
        // Update the start position of the next token.
        _tokenStart = _current
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
        } while !reachedEOF()
        
        // Remove the EOF token if requested.
        if !includeEOF { _ = _tokens.popLast() }
            
        // Since struct arrays are a value type we can return the internal Token array
        // and it should be copied.
        return _tokens
    }
}
