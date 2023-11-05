//
//  Tokeniser.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public class Tokeniser {
    // MARK: - Properties
    
    /// A mapping of Objo's reserved words and their token type.
    private let _reservedWords: [String : TokenType] = [
        "and"         : .and,
        "as"          : .as_,
        "assert"      : .assert,
        "breakpoint"  : .breakpoint,
        "case"        : .case_,
        "class"       : .class_,
        "continue"    : .continue_,
        "constructor" : .constructor,
        "do"          : .do_,
        "else"        : .else_,
        "exit"        : .exit,
        "export"      : .export,
        "false"       : .boolean,
        "for"         : .for_,
        "foreach"     : .foreach,
        "foreign"     : .foreign,
        "function"    : .function,
        "if"          : .if_,
        "import"      : .import_,
        "in"          : .in_,
        "is"          : .is_,
        "loop"        : .loop,
        "not"         : .not,
        "nothing"     : .nothing,
        "or"          : .or,
        "return"      : .return_,
        "select"      : .select,
        "static"      : .static_,
        "super"       : .super_,
        "then"        : .then,
        "this"        : .this,
        "true"        : .boolean,
        "until"       : .until,
        "var"         : .var_,
        "while"       : .while_,
        "xor"         : .xor
    ]
    
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
    /// `true` if the tokenising is in the middle of tokenising a list.
    private var _tokenisingList = false
    /// The tokens to return.
    private var _tokens: [Token] = []
    /// The 0-based index in `_chars` that the current token starts at.
    private var _tokenStart: Int = 0
    /// The number of unclosed curly braces.
    private var _unclosedCurlyCount = 0
    /// The number of unclosed parentheses.
    private var _unclosedParenCount = 0
    /// The number of unclosed square brackets.
    private var _unclosedSquareCount = 0
    
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
    
    /// Creates and adds a token representing either a static or instance field identifier.
    ///
    /// Assumes that `_current` points to the character immediately following the last `_` **and**
    /// that this character is a letter.
    /// Field identifiers start with a single underscore, e.g: `_width`.
    /// Static field identifiers start with two underscores, e.g: `__version`
    /// Identifiers can contain any combination of letters, underscores or numbers.
    private func addFieldIdentifier(isStatic: Bool) {
        var lexemeChars: [Character] = ["_"]
        if isStatic { lexemeChars.append("_") }
        
        while peek().isASCIILetterDigitOrUnderscore() {
            lexemeChars.append(advance())
        }
        
        let type: TokenType = isStatic ? .staticFieldIdentifier : .fieldIdentifier
        
        _tokens.append(BaseToken(type: type, start: _tokenStart, line: _lineNumber, lexeme: String(lexemeChars), scriptId: _scriptId))
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
    
    /// Adds either a variable identifier, keyword, boolean or the nothing token.
    ///
    /// Assumes we've already consumed the first character:
    ///
    /// ```
    /// name
    ///  ^
    /// ```
    private func addIdentifierOrReservedWord() {
        var chars: [Character] = [previous()]
        
        // Consume all alphanumeric characters and underscores.
        while peek().isASCIILetterDigitOrUnderscore() {
            chars.append(advance())
        }
        
        let lexeme = String(chars)
        
        // Determine the token's type based on it's lexeme, defaulting to an identifier.
        var type: TokenType = _reservedWords[lexeme, default: .identifier]
        
        switch type {
        case .boolean:
            _tokens.append(BooleanToken(value: Bool(lexeme)!, start: _tokenStart, line: _lineNumber, lexeme: lexeme, scriptId: _scriptId))
            
        default:
            // Objo needs to know if an identifier begins with an uppercase identifier or not.
            if type == .identifier {
                if lexeme.first!.isUppercase { type = .uppercaseIdentifier }
            }
            
            // Add this token.
            _tokens.append(makeToken(type: type, hasLexeme: true))
        }
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
        var lexemeChars: [Character] = [previous()]
        
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
    
    /// Attempts to add a string literal token.
    ///
    /// String literals begin and end with a double quote (`"`).
    /// They may contain >= 0 escaped double quotes (`""`).
    /// This method assumes that the current character being evaluated is
    /// immediately after the opening double quote:
    /// ```
    /// "Hello"
    ///  ^
    /// ```
    ///
    /// Objo strings can also contain Unicode characters which are represented in two ways:
    /// 1. A `\u` followed by four hex digits can be used to specify a Unicode code point:
    ///
    /// ```objo
    /// "\u0041\u0b83\u00DE" // AஃÞ
    /// ```
    ///
    /// 2. A capital `\U` followed by eight hex digits allows Unicode code points outside of the basic multilingual plane:
    ///
    /// ```objo
    /// "\U0001F64A\U0001F680" // 🙊🚀
    /// ```
    private func addString() throws {
        var lexemeChars: [Character] = []
        
        // Keep consuming until we hit a `"`.
        var terminated = false
        var c: Character = "\0"
        var lastChar: Character = "\0"
    outerWhile: while !atEnd() {
            c = advance()
            
            if c == "\"" {
                // If the next character is a `"` then this is an escaped quote.
                if match("\"") {
                    lexemeChars.append(c)
                    lastChar = previous()
                    continue
                } else {
                    terminated = true
                    break outerWhile
                }
            } else if c == "\\" && lastChar != "\\" {
                let peekChar = peek()
                if peekChar == "u" {
                    // Move past `u`.
                    eat()
                    // Consume 4 hex digits and compute the codepoint.
                    let codePoint: UInt32 = try consumeHexValue(digits: 4, errorType: .syntaxError)
                    // Try to convert the codepoint to a character.
                    guard let unicode = Character(codepoint: codePoint) else {
                        throw error(type: .syntaxError, message: "Invalid Unicode escape sequence.")
                    }
                    lexemeChars.append(unicode)
                } else if peekChar == "U" {
                    // Move past `u`.
                    eat()
                    // Consume 8 hex digits and compute the codepoint.
                    let codePoint: UInt32 = try consumeHexValue(digits: 8, errorType: .syntaxError)
                    // Try to convert the codepoint to a character.
                    guard let unicode = Character(codepoint: codePoint) else {
                        throw error(type: .syntaxError, message: "Invalid Unicode escape sequence.")
                    }
                    lexemeChars.append(unicode)
                }
            } else if c == "\n" {
                break outerWhile
            } else {
                lexemeChars.append(c)
            }
            lastChar = previous()
        }
        
        // Make sure the literal was terminated.
        if !terminated {
            throw error(type: .syntaxError, message: "Unterminated string literal. Expected a closing double quote.")
        }
        
        // Add this string token.
        _tokens.append(BaseToken(type: .string, start: _tokenStart, line: _lineNumber, lexeme: String(lexemeChars), scriptId: _scriptId))
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
            if peek() == "\n" {
                addToken(makeToken(type: .endOfLine))
                break
            } else if atEnd() {
                break
            } else {
                eat()
            }
        }
    }
    
    /// Consumes the specified number of contiguous hex digits. Throws if unable to consume
    /// the required number.
    private func consumeHexValue(digits: Int, errorType: TokeniserError.ErrorType) throws -> UInt32 {
        let message = "Expected \(digits) hex digits."
        
        guard digits > 0 else {
            throw error(type: errorType, message: message)
        }
        
        // Get the required hex characters.
        var chars: [Character] = []
        for _ in 1...digits {
            if !peek().isHexDigit {
                throw error(type: errorType, message: message)
            } else {
                chars.append(advance())
            }
        }
        
        // Convert the hex characters into an integer.
        return UInt32(String(chars), radix: 16)!
    }
    
    /// Consumes the current character.
    private func eat() {
        _current += 1
    }
    
    /// Returns a tokeniser error of the specified type at the current position.
    private func error(type: TokeniserError.ErrorType, message: String) -> TokeniserError {
        return TokeniserError(line: _lineNumber, message: message, scriptId: _scriptId, start: _tokenStart, type: type)
    }
    
    /// Called when we encounter an underscore at the end of a line.
    ///
    /// Assumes that the subsequent newline character has already been consumed.
    /// We need to advance past any spaces or tabs until we hit a non-whitespace character.
    /// If we hit a newline or the end of the source code before we find a non-whitespace
    /// character then we throw an error.
    private func handleLineContinuation() throws {
        _lineNumber += 1
        while matchSpaceOrTab() {}
        if atEnd() {
            throw error(type: .syntaxError, message: "Unexpected end of source code. Expected a non-whitespace character following the line continuation operator.")
        }
    }
    
    /// A convenience function for returning an end of file token.
    private func makeEofToken() -> Token {
        return BaseToken(type: .eof, start: _chars.count, line: _lineNumber, lexeme: nil, scriptId: _scriptId)
    }
    
    /// Returns a base token of the specified type beginning at _tokenStart on the current line in the current script.
    private func makeToken(type: TokenType, hasLexeme: Bool = false) -> BaseToken {
        if hasLexeme {
            let lexeme = String(_chars[_tokenStart..._current - 1])
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
    
    /// If the next character is a space or a horizontal tab then we consume it and return `true`.
    /// Otherwise we leave the character alone and return `false`.
    private func matchSpaceOrTab() -> Bool {
        switch peek() {
        case " ", "\t":
            eat()
            return true
        default:
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
            addToken(makeToken(type: .endOfLine))
            addToken(makeToken(type: .eof))
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
        // Single character tokens.
        // ====================================================================
        switch c {
        case "(":
            addToken(makeToken(type: .lparen))
            _unclosedParenCount += 1
            return
            
        case ")":
            addToken(makeToken(type: .rparen))
            _unclosedParenCount -= 1
            if _unclosedParenCount < 0 {
                throw error(type: .syntaxError, message: "Unmatched closing parenthesis.")
            }
            return
            
        case "{":
            addToken(makeToken(type: .lcurly))
            _unclosedCurlyCount += 1
            return
            
        case "}":
            addToken(makeToken(type: .rcurly))
            _unclosedCurlyCount -= 1
            if _unclosedCurlyCount < 0 {
                throw error(type: .syntaxError, message: "Unmatched closing curly bracket.")
            }
            return
            
        case "[":
            addToken(makeToken(type: .lsquare))
            _unclosedSquareCount += 1
            _tokenisingList = true
            return
            
        case "]":
            addToken(makeToken(type: .rsquare))
            _unclosedSquareCount -= 1
            if _unclosedSquareCount < 0 {
                throw error(type: .syntaxError, message: "Unmatched closing square bracket.")
            }
            if _unclosedSquareCount == 0 { _tokenisingList = false }
            return
            
        case ",":
            addToken(makeToken(type: .comma))
            return
            
        case "&":
            addToken(makeToken(type: .ampersand))
            return
            
        case "|":
            addToken(makeToken(type: .pipe))
            return
            
        case "^":
            addToken(makeToken(type: .caret))
            return
            
        case "~":
            addToken(makeToken(type: .tilde))
            return
            
        case ":":
            addToken(makeToken(type: .colon))
            return
            
        case ";":
            addToken(makeToken(type: .semicolon))
            return
            
        case "?":
            addToken(makeToken(type: .query))
            return
            
        case "%":
            addToken(makeToken(type: .percent))
            return
            
        default:
            break
        }
        
        // ====================================================================
        // Single OR multiple character tokens.
        // `c` is a character that can occur on its own or can occur in
        // combination with one or more characters.
        // ====================================================================
        switch c {
        case "=":
            if match("=") {
                addToken(makeToken(type: .equalEqual))
                return
            } else {
                addToken(makeToken(type: .equal))
                return
            }
            
        case ".":
            if match(".") {
                if match(".") {
                    addToken(makeToken(type: .dotDotDot))
                    return
                } else {
                    if match("<") {
                        addToken(makeToken(type: .dotDotLess))
                        return
                    } else {
                        throw error(type: .unexpectedCharacter, message: "Unknown operator `..`.")
                    }
                }
            } else {
                addToken(makeToken(type: .dot))
                return
            }
            
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
            
        case "-":
            if match("=") {
                addToken(makeToken(type: .minusEqual, hasLexeme: true))
                return
            } else if match("-") {
                addToken(makeToken(type: .minusMinus, hasLexeme: true))
                return
            } else {
                addToken(makeToken(type: .minus, hasLexeme: true))
                return
            }
            
        case "*":
            if match("=") {
                addToken(makeToken(type: .starEqual))
                return
            } else {
                addToken(makeToken(type: .star))
                return
            }
            
        case "/":
            if match("=") {
                addToken(makeToken(type: .forwardSlashEqual))
                return
            } else {
                addToken(makeToken(type: .forwardSlash))
                return
            }
            
        case "<":
            if match(">") {
                addToken(makeToken(type: .notEqual))
                return
            } else if match("=") {
                addToken(makeToken(type: .lessEqual))
                return
            } else if match("<") {
                addToken(makeToken(type: .lessLess))
                return
            } else {
                addToken(makeToken(type: .less))
                return
            }
            
        case ">":
            if match("=") {
                addToken(makeToken(type: .greaterEqual))
                return
            } else if match(">") {
                addToken(makeToken(type: .greaterGreater))
                return
            } else {
                addToken(makeToken(type: .greater))
                return
            }
            
        default:
            break
        }
        
        // ====================================================================
        // Strings.
        // ====================================================================
        if c == "\"" {
            try addString()
            return
        }
        
        // ====================================================================
        // The underscore.
        // Underscores represent the line continuation marker if they are
        // immediately followed by a newline or they can indicate the
        // beginning of an identifier.
        // ====================================================================
        if c == "_" {
            if match("_") {
                if peek().isASCIILetter() {
                    // A static field identifier (e.g. `__version`).
                    addFieldIdentifier(isStatic: true)
                    return
                } else {
                    throw error(type: .unexpectedCharacter, message: "Expected a letter after `__`.")
                }
            } else if peek().isASCIILetter() {
                // A class field identifier (e.g. `_width`).
                addFieldIdentifier(isStatic: false)
                return
            } else {
                // Could be the line continuation marker.
                // Edge case: Discard trailing whitespace between the underscore and the newline 
                // character.
                while matchSpaceOrTab() {}
                
                // Edge case: Handle a comment after the line continuation marker.
                if match("#") {
                    while true {
                        if peek() == "\n" {
                            break
                        } else if atEnd() {
                            break
                        } else {
                            eat()
                        }
                    }
                }
                
                if match("\n") {
                    try handleLineContinuation()
                    return
                } else {
                    throw error(type: .unexpectedCharacter, message: "Expected either a letter or end of line after the line continuation marker.")
                }
            }
        }
        
        // =================================================================
        // Identifiers, keywords, booleans and nothing.
        // =================================================================
        // TODO: Implement.
        if c.isASCIILetter() {
            addIdentifierOrReservedWord()
            return
        }
        
        throw error(type: .unexpectedCharacter, message: "Unexpected character.")
    }
    
    /// Returns the previously consumed character or the null character (\0) if this is
    /// the first character.
    private func previous() -> Character {
        if _current - 1 >= 0 {
            return _chars[_current - 1]
        } else {
            return "\0"
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
        _tokenisingList = false
        _tokenStart = 0
        _tokens = []
        _unclosedCurlyCount = 0
        _unclosedParenCount = 0
        _unclosedSquareCount = 0
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
                    addToken(makeToken(type: .endOfLine))
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
