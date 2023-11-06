//
//  Parser.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public class Parser {
    // MARK: - Enumerations
    
    public enum Precedence: Int, Comparable {
        case none = 0
        case lowest
        case assignment
        case conditional
        case logicalOr
        case logicalXor
        case logicalAnd
        case equality
        case is_
        case comparison
        case bitwiseOr
        case bitwiseXor
        case bitwiseAnd
        case bitwiseShift
        case range
        case term
        case factor
        case postfix
        case unary
        case call
        case primary
        
        public static func <(lhs: Precedence, rhs: Precedence) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Static properties
    
    /// An array of the built-in types that cannot be inherited from.
    private static let notInheritable = [
        "Boolean", "List", "Map", "Nothing", "Number", "String", "System"
    ]
    
    /// An array of the operator types that can be overloaded.
    private static let overloadableOperators: [TokenType] = [
        .ampersand, .dotDotLess, .dotDotDot, .equalEqual, .forwardSlash, .greater, .greaterEqual, .greaterGreater,
        .is_, .less, .lessLess, .lessEqual, .lsquare, .minus, .notEqual, .percent, .pipe, .not, .plus,
        .star, .tilde
    ]
    
    /// An array of the operator types that are overloadable unary operators.
    private static let overloadableUnaryOperators: [TokenType] = [.minus, .not, .tilde]
    
    /// Objo's grammar rules.
    /// Represents our Pratt parser for parsing expressions.
    public static let rules: [TokenType : GrammarRule] = [
        .ampersand              : binary(precedence: .bitwiseAnd),
        .and                    : logical(precedence: .logicalAnd),
        .assert                 : unused(),
        .as_                    : unused(),
        .boolean                : prefix(parselet: LiteralParselet()),
        .breakpoint             : unused(),
        .caret                  : binary(precedence: .bitwiseXor),
        .class_                 : unused(),
        .colon                  : GrammarRule(prefix: nil, infix: KeyValueParselet(), precedence: .range),
        .comma                  : unused(),
        .constructor            : unused(),
        .continue_              : unused(),
        .dot                    : GrammarRule(prefix: nil, infix: DotParselet(), precedence: .call),
        .dotDotLess             : GrammarRule(prefix: nil, infix: RangeParselet(), precedence: .range),
        .dotDotDot              : GrammarRule(prefix: nil, infix: RangeParselet(), precedence: .range),
        .else_                  : unused(),
        .eof                    : unused(),
        .endOfLine              : unused(),
        .equal                  : unused(),
        .equalEqual             : binary(precedence: .equality),
        .exit                   : unused(),
        .export                 : unused(),
        .fieldIdentifier        : prefix(parselet: FieldParselet()),
        .foreign                : unused(),
        .forwardSlash           : binary(precedence: .factor),
        .forwardSlashEqual      : unused(),
        .for_                   : unused(),
        .foreach                : unused(),
        .function               : unused(),
        .greater                : binary(precedence: .comparison),
        .greaterEqual           : binary(precedence: .comparison),
        .greaterGreater         : binary(precedence: .bitwiseShift),
        .identifier             : prefix(parselet: VariableParselet()),
        .if_                    : GrammarRule(prefix: nil, infix: ConditionalParselet(), precedence: .assignment),
        .import_                : unused(),
        .in_                    : unused(),
        .is_                    : GrammarRule(prefix: nil, infix: IsParselet(), precedence: .is_),
        .lcurly                 : prefix(parselet: MapParselet()),
        .less                   : binary(precedence: .comparison),
        .lessEqual              : binary(precedence: .comparison),
        .lessLess               : binary(precedence: .bitwiseShift),
        .lparen                 : GrammarRule(prefix: GroupParselet(), infix: CallParselet(), precedence: .call),
        .lsquare                : GrammarRule(prefix: ListParselet(), infix: SubscriptParselet(), precedence: .call),
        .minus                  : GrammarRule(prefix: UnaryParselet(), infix: BinaryParselet(precedence: .term, rightAssociative: false), precedence: .term),
        .minusMinus             : postfix(),
        .minusEqual             : unused(),
        .notEqual               : binary(precedence: .equality),
        .nothing                : prefix(parselet: LiteralParselet()),
        .not                    : prefix(parselet: UnaryParselet()),
        .number                 : prefix(parselet: LiteralParselet()),
        .or                     : logical(precedence: .logicalOr),
        .percent                : binary(precedence: .factor),
        .pipe                   : binary(precedence: .bitwiseOr),
        .plus                   : binary(precedence: .term),
        .plusEqual              : unused(),
        .plusPlus               : postfix(),
        .query                  : unused(),
        .rcurly                 : unused(),
        .return_                : unused(),
        .rparen                 : unused(),
        .rsquare                : unused(),
        .semicolon              : unused(),
        .star                   : binary(precedence: .factor),
        .starEqual              : unused(),
        .static_                : unused(),
        .staticFieldIdentifier  : prefix(parselet: FieldParselet()),
        .string                 : prefix(parselet: LiteralParselet()),
        .super_                 : prefix(parselet: SuperParselet()),
        .then                   : unused(),
        .this                   : prefix(parselet: ThisParselet()),
        .tilde                  : GrammarRule(prefix: UnaryParselet(), infix: nil, precedence: .none),
        .underscore             : unused(),
        .uppercaseIdentifier    : prefix(parselet: ClassParselet()),
        .var_                   : unused(),
        .while_                 : unused(),
        .xor                    : logical(precedence: .logicalXor)
        ]
    
    // MARK: - Static methods
    
    /// A convenience method for returning a new grammar rule for a binary operator.
    private static func binary(precedence: Precedence, rightAssociative: Bool = false) -> GrammarRule {
        return GrammarRule(prefix: nil, infix: BinaryParselet(precedence: precedence, rightAssociative: rightAssociative), precedence: precedence)
    }
    
    /// A convenience method for returning a new grammar rule for a logical operator.
    private static func logical(precedence: Precedence) -> GrammarRule {
        return GrammarRule(prefix: nil, infix: LogicalParselet(precedence: precedence), precedence: precedence)
    }
    
    /// A convenience method for returning a new grammar rule for a postfix operator.
    private static func postfix() -> GrammarRule {
        return GrammarRule(prefix: nil, infix: PostfixParselet(), precedence: .postfix)
    }
    
    /// A convenience method for returning a new grammar rule for a prefix operator with the `.none` precedence.
    private static func prefix(parselet: PrefixParselet) -> GrammarRule {
        return GrammarRule(prefix: parselet, infix: nil, precedence: .none)
    }
    
    /// A convenience method for returning a new GrammarRule that is unused.
    private static func unused() -> GrammarRule {
        return GrammarRule(prefix: nil, infix: nil, precedence: .none)
    }
    
    // MARK: - Instance properties
    
    /// The abstract syntax tree being constructed by the parser.
    private var _ast: [Stmt] = []
    /// The token currently being evaluated.
    private var _current: Token?
    /// The index in `_tokens` of the token currently being processed.
    private var _currentIndex: Int = -1
    /// Any errors that have occurred during the parsing process.
    private var _errors: [ParserError] = []
    /// The previously evaluated token (will be `nil` when the parser begins).
    private var _previous: Token?
    /// The array of tokens that this parser will process.
    private var _tokens: [Token] = []
    
    // MARK: - Public methods
    
    public init() {}
    
    /// Parses an expression.
    /// Public so parselets can access.
    public func expression() throws -> Expr {
        return try parsePrecedence(.lowest)
    }
    
    /// Returns `true` if the current token matches the specified type.
    /// Similar to `match()` but does **not** consume the current token if there is a match.
    ///
    /// Public so parselets can access it.
    public func check(_ type: TokenType) -> Bool {
        if _current?.type == type { return true }
        return false
    }

    /// Returns `true` if the current token matches any of the specified types.
    /// Similar to `match()` but does **not** consume the current token if there is a match.
    ///
    /// Public so parselets can access it.
    public func check(_ types: TokenType...) -> Bool {
        for type in types {
            if _current?.type == type { return true }
        }
        return false
    }
    
    /// If the current token matches `expected` then it's consumed.
    /// If not, we thorw an error with `message`.
    ///
    /// Public so parselets can access it.
    public func consume(_ expected: TokenType, message: String? = nil) throws {
        guard let current = _current else {
            throw ParserError(message: "Expected \(expected) but got an internal nil error instead.", location: nil)
        }
        
        if current.type != expected {
            throw ParserError(message: message ?? "Expected \(expected) but got \(current.type) instead.", location: current)
        } else {
            advance()
        }
    }
    
    /// If the current token matches any of the types in `expected` then it's consumed.
    /// If not, we throw an error with `message`.
    ///
    /// Public so parselets can access it.
    public func consume(_ expected: TokenType..., message: String? = nil) throws {
        guard let current = _current else {
            throw ParserError(message: "Internal nil value of the current token in the parser.", location: nil)
        }
        
        for type in expected {
            if type == current.type {
                advance()
                return
            }
        }
        
        throw ParserError(message: message ?? "Unexpected \(current.type) token.", location: current)
    }
    
    /// If the current token matches any of the specified types it's consumed (i.e. "ditched").
    /// Identical to `match()` except doesn't return a Bool.
    /// Mostly used for ignoring optional new lines.
    ///
    /// Public so parselets can access it.
    public func ditch(_ types: TokenType...) {
        for type in types {
            if check(type) {
                advance()
                return
            }
        }
    }
    
    /// Raises a `ParserError` at the current location. If the error is not at the current location,
    /// `location` may be passed instead.
    public func error(message: String, location: Token? = nil) throws {
        throw ParserError(message: message, location: location ?? _current)
    }
    
    /// If the current token matches any of the types in `expected` then it's consumed and returned.
    /// If not, we throw an error with `message`.
    ///
    /// Public access so parselets can access it.
    public func fetch(_ expected: TokenType..., message: String? = nil) throws -> Token {
        guard let current = _current else {
            throw ParserError(message: "Internal nil value of the current token in the parser.", location: nil)
        }
        
        for type in expected {
            if type == current.type {
                advance()
                return _previous!
            }
        }
        
        throw ParserError(message: message ?? "Unexpected \(current.type) token.", location: current)
    }
    
    /// If the current token matches any of the specified types it is consumed and
    /// the function returns `true`. Otherwise it just returns `false`.
    ///
    /// Public so parselets can access it.
    public func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }
    
    /// If the current token matches any of the specified types it is consumed and
    /// the function returns `true`. Otherwise it just returns `false`.
    ///
    /// Public so parselets can access it.
    public func match(_ types: [TokenType]) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }
    
    /// Parses an array of tokens into an abstract syntax tree.
    public func parse(tokens: [Token]) -> [Stmt] {
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
            } catch {
                // Unrecoverable error. Return the AST in its current state.
                return _ast
            }
        }

        return _ast
    }
    
    /// Parses and returns an expression at the given precedence level or higher.
    ///
    /// This is the main entry point for the top-down operator precedence parser.
    public func parsePrecedence(_ precedence: Precedence) throws -> Expr {
        advance()
        
        // We just consumed the prefix token.
        let rule = getRule(type: _previous!.type)
        
        // Get the prefix parselet.
        guard let prefix = rule?.prefix else {
            throw ParserError(message: "Expected an expression. Instead got `\(_current!.type)`.", location: _current)
        }
        
        // Track if the precedence of the surrounding expression is low enough to
        // allow an assignment inside this one. We can't parse an assignment like
        // a normal expression because it requires us to handle the LHS specially
        // (it needs to be an lvalue, not an rvalue).
        // So, for each of the kinds of expressions that are valid
        // lvalues (e.g. names, subscripts, fields, etc) we pass in whether or not
        // it appears in a context loose enough to allow "=".
        // If so, it will parse the "=" itself and handle it appropriately.
        let canAssign = precedence <= .conditional
        
        var left = try prefix.parse(parser: self, canAssign: canAssign)
        
        // Get the precedence of the rule for the current token, defaulting to none if this token has no rule defined.
        var rulePrecedence: Precedence = getRule(type: _current!.type) == nil ? .none : getRule(type: _current!.type)!.precedence
        
        // Keep parsing whilst the precedence is less that the current rule precedence.
        while precedence < rulePrecedence {
            advance()
            
            // Make sure there is an infix parselet for the current token.
            guard let infix = getRule(type: _previous!.type)!.infix else {
                throw ParserError(message: "No infix rule for \(_previous!.type) token type.", location: _current)
            }
            
            // Parse the left hand expression.
            left = try infix.parse(parser: self, left: left, canAssign: canAssign)
            
            // Since the current token has changed, get the grammar rule for it.
            let rule = getRule(type: _current!.type)
            
            // Figure out the precedence of the current rule.
            rulePrecedence = rule == nil ? .none : rule!.precedence
        }
        
        if canAssign && match(.equal) {
            throw ParserError(message: "Invalid assignment target.", location: _current)
        }
        
        return left
    }
    
    /// Returns the previously evaluated token.
    public func previous() -> Token? {
        return _previous
    }
    
    public func reset() {
        _ast = []
        _current = nil
        _currentIndex = -1
        _errors = []
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
    
    /// Parses an `assert` statement. Assumes the parser has just consumed the `assert` keyword.
    ///
    /// Format:
    /// ```objo
    /// assert(condition, message)
    /// ```
    private func assertStatement() throws -> AssertStmt {
        let location = _previous!
        
        try consume(.lparen, message: "Expected an opening parenthesis after the assert keyword.")
        
        let condition = try expression()
        
        try consume(.comma, message: "Expected a comma after the condition.")
        
        let message = try expression()
        
        try consume(.rparen, message: "Expected a closing parenthesis after the assert message.")
        
        try consume(.endOfLine, message: "Expected a new line after the assert statement.")
        
        return AssertStmt(condition: condition, message: message, location: location)
    }
    
    /// returns `true` if we've reached the end of the token stream.
    private func atEnd() -> Bool {
        return _currentIndex >= _tokens.count || _current?.type == .eof
    }
    
    /// Parses a block of statements.
    /// Assumes the parser has just consumed the leading `{`.
    private func block() throws -> BlockStmt {
        let openingBrace = _previous!
        
        var statements: [Stmt] = []
        
        ditch(.endOfLine)
        
        while !check(.rcurly, .eof) {
            try statements.append(declaration())
            ditch(.endOfLine)
        }
        
        let closingBrace = try fetch(.rcurly, message: "Expected a closing brace after the block.")
        
        // Edge cases: The `else` keyword is permitted after a closing brace in `if` statements and
        // the `loop` keyword is permitted after a closing brace in `do` loops.
        if !check(.else_, .loop) {
            try consume(.endOfLine, message: "Expected a new line after the closing brace.")
        }
        
        return BlockStmt(statements: statements, openingBrace: openingBrace, closingBrace: closingBrace)
    }
    
    /// Parses a `breakpoint` statement.
    /// Assumes the parser has just consumed the `breakpoint` keyword.
    private func breakpointStatement() throws -> BreakpointStmt {
        let keyword = _previous!
        
        try consume(.endOfLine, message: "Expected a new line after the `breakpoint` statement.")
        
        return BreakpointStmt(keyword: keyword)
    }
    
    /// Parses a class declaration statement.
    /// Assumes the parser has just consumed the `class` keyword token.
    ///
    /// ```objo
    /// class Doctor is Person {
    ///  constructor(name) {}
    ///  foreign static fsmethod()
    ///  foreign fimethod()
    ///  static smethod() {}
    ///  imethod() {}
    /// }
    /// ```
    private func classDeclaration(isForeign: Bool) throws -> ClassDeclStmt {
        let classKeyword = _previous!
        
        let identifier = try fetch(.uppercaseIdentifier, message: "Expected a class name beginning with an uppercase letter.")
        
        let className = identifier.lexeme!
        
        // Optional superclass.
        var superclass: String?
        if match(.is_) {
            // Edge case: Attempting to inherit from a built-in type.
            if Parser.notInheritable.contains(_current!.lexeme!) {
                try error(message: "Classes cannot inherit from built-in types.")
            }
            superclass = try fetch(.uppercaseIdentifier, message: "Expected a superclass name beginning with an uppercase letter.").lexeme
        }
        
        try consume(.lcurly, message: "Expected an opening curly brace after the class name.")
        
        ditch(.endOfLine)
        
        // Optional constructors and methods.
        var methods: [String : MethodDeclStmt] = [:]
        var staticMethods: [String : MethodDeclStmt] = [:]
        var foreignInstance: [String : ForeignMethodDeclStmt] = [:]
        var foreignStatic: [String : ForeignMethodDeclStmt] = [:]
        var constructors: [ConstructorDeclStmt] = []
        var cdecl: ConstructorDeclStmt
        var constructorArities: [Int : Bool] = [:] // key = constructor arity, value not used.
        
        while !check(.rcurly, .eof) {
            if match(.constructor) {
                
                cdecl = try constructorDeclaration(className: className)
                
                if constructorArities[cdecl.arity] != nil {
                    let s = cdecl.arity == 1 ? "a single parameter" : "\(cdecl.arity) parameters"
                    try error(message: "A constructor with \(s) has already be declared.")
                } else {
                    constructors.append(cdecl)
                    constructorArities[cdecl.arity] = false
                }
                
            } else if match(.foreign) {
                
                var f: ForeignMethodDeclStmt
                if match(.static_) {
                    // Foreign STATIC method declaration.
                    f = try foreignMethodDeclaration(className: className, isStatic: true)
                    if staticMethods[f.signature] != nil || foreignStatic[f.signature] != nil {
                        try error(message: "Duplicate method definition: \(f.signature)", location: f.location)
                    } else {
                        foreignStatic[f.signature] = f
                    }
                    
                } else {
                    // Foreign INSTANCE method declaration.
                    f = try foreignMethodDeclaration(className: className, isStatic: false)
                    if methods[f.signature] != nil || foreignInstance[f.signature] != nil  {
                        try error(message: "Duplicate method definition: \(f.signature)", location: f.location)
                    } else {
                        foreignInstance[f.signature] = f
                    }
                }
                
            } else if match(.static_) {
                
                // Native STATIC method declaration.
                let sm = try methodDeclaration(className: className, isStatic: true)
                
                if staticMethods[sm.signature] != nil {
                    try error(message: "Duplicate method definition: \(sm.signature)", location: sm.location)
                }
                
                if foreignInstance[sm.signature] != nil && foreignInstance[sm.signature]!.isStatic {
                    try error(message: "Duplicate method definition: \(sm.signature)", location: sm.location)
                }
                
                staticMethods[sm.signature] = sm
                
            } else {
                
                let m = try methodDeclaration(className: className, isStatic: false)
                
                if methods[m.signature] != nil {
                    try error(message: "Duplicate method definition: \(m.signature)", location: m.location)
                }
                if foreignInstance[m.signature] != nil && !foreignInstance[m.signature]!.isStatic {
                    try error(message: "Duplicate method definition: \(m.signature). Conflicts with an existing foreign instance method.", location: m.location)
                }
                
                methods[m.signature] = m
            }
            
            ditch(.endOfLine)
        }
        
        try consume(.rcurly, message: "Expected a closing curly brace after the class body.")
        
        return ClassDeclStmt(superclass: superclass, identifier: identifier, constructors: constructors, staticMethods: staticMethods, methods: methods, foreignInstanceMethods: foreignInstance, foreignStaticMethods: foreignStatic, classKeyword: classKeyword, isForeign: isForeign)
    }
    
    /// Parses a class constructor declaration.
    ///
    /// Assumes the parser has just consumed the `constructor` keyword.
    /// ```
    /// constructor(params){}
    /// ```
    private func constructorDeclaration(className: String) throws -> ConstructorDeclStmt {
        let keyword = _previous!
        
        try consume(.lparen, message: "Expected an opening parenthesis after the `constructor` keyword.")
        
        // Optional parameters.
        var parameters: [Token] = []
        if !check(.rparen) {
            repeat {
                parameters.append(try fetch(.identifier, message: "Expected parameter name."))
            } while !match(.comma)
        }
        
        try consume(.rparen, message: "Expected a closing parenthesis after the constructor's parameters.")
        
        try consume(.lcurly, message: "Expected an opening curly brace after the constructor's parameters.")
        
        return try ConstructorDeclStmt(className: className, parameters: parameters, body: try block(), constructorKeyword: keyword)
    }
    
    /// Parses a `continue` statement.
    /// Assumes the `continue` keyword has just been consumed.
    private func continueStatement() throws -> ContinueStmt {
       let keyword = _previous!
        
        try consume(.endOfLine, message: "Expected a new line after the `continue` keyword.")
        
        return ContinueStmt(keyword: keyword)
    }
    
    /// Parses a declaration into a `Stmt`.
    ///
    /// An Objo program is a series of statements. Statements produce a side effect.
    /// Declarations are a type of statement that bind new identifiers.
    private func declaration() throws -> Stmt {
        ditch(.endOfLine)
        
        if match(.var_) {
            
            return try varDeclaration()
            
        } else if match(.function) {
            
            return try functionDeclaration()
            
        } else if match(.class_) {
            
            return try classDeclaration(isForeign: false)
            
        } else if match(.foreign) {
            
            try consume(.class_, message: "Expected `class` after the `foreign` keyword.")
            return try classDeclaration(isForeign: true)
            
        } else {
            
            return try statement()
            
        }
    }
    
    /// Parses an `exit` statement.
    /// Assumes the `exit` keyword has just been consumed.
    private func exitStatement() throws -> ExitStmt {
        let exitKeyword = _previous!
        
        try consume(.endOfLine, message: "Expected a new line after the `exit` keyword.")
        
        return ExitStmt(exitKeyword: exitKeyword)
    }
    
    /// Parses an expression and wraps it up inside a statement.
    /// `terminator` will be consumed.
    ///
    /// `terminator` is the token that is required to occur after the declaration to be valid.
    private func expressionStatement(terminator: TokenType = .endOfLine) throws -> ExpressionStmt {
        ditch(.endOfLine)
        
        // Store the location of the start of the expression.
        let location = _current!
        
        // Consume the expression.
        let expr = try expression()
        
        // Most expression statements expect a new line after them but some (such as within a
        // `for` loop initialiser) require something else (e.g. a semicolon).
        if terminator == .endOfLine || terminator == .eof {
            if check(.rcurly) {
                // Edge case: A statement immediately preceding the closing brace of a block. Do nothing.
            } else {
                try consume(.endOfLine, .eof, message: "Expected a new line or EOF after expression statement.")
            }
        } else  {
            try consume(terminator, message: "Expected a \(terminator) after the expression.")
        }
        
        return ExpressionStmt(expression: expr, location: location)
    }
    
    /// Parses a `foreach` loop.
    /// Assumes we have just consumed the `foreach` keyword.
    ///
    /// Syntax:
    ///
    /// ```objo
    /// foreach i in RANGE {
    ///  statements
    /// }
    /// ```
    private func foreachStatement() throws -> ForEachStmt {
        let foreachKeyword = _previous!
        
        let loopCounter = try fetch(.identifier, message: "Expected a name for the loop counter after the `foreach` keyword.")
        
        try consume(.in_, message: "Expected the `in` keyword after the loop counter name.")
        
        let range = try expression()
        
        ditch(.endOfLine)
        
        try consume(.lcurly, message: "Expected an opening curly brace after the range expression.")
        
        return ForEachStmt(foreachKeyword: foreachKeyword, loopCounter: loopCounter, range: range, body: try block())
    }
    
    /// Parses a foreign class method declaration (instance or static).
    ///
    /// There are two types of foreign methods: regular and setters.
    /// Regular methods may or may not return values and can accept any number of arguments.
    /// Setters do not return a value and must have one argument. Format:
    /// ```
    /// age=(value) # Note the `=` to denote it's a setter.
    /// ```
    /// If `isStatic` is `true` then this is a static method declaration.
    private func foreignMethodDeclaration(className: String, isStatic: Bool) throws -> ForeignMethodDeclStmt {
        if match(Parser.overloadableOperators) {
            return try overloadedOperator(className: className, op: _previous!, isStatic: isStatic, isForeign: true) as! ForeignMethodDeclStmt
        }
        
        let identifier = try fetch(.identifier)
        
        let isSetter = match(.equal)
        
        try consume(.lparen, message: "Expected an opening parenthesis after the method's name.")
        
        // Optional parameters.
        var parameters: [Token] = []
        if !check(.rparen) {
            repeat {
                parameters.append(try fetch(.identifier, message: "Expected parameter name."))
            } while !match(.comma)
        }
        
        if isSetter && parameters.count != 1 {
            try error(message: "Setters must have exactly one parameter.", location: identifier)
        }
        
        try consume(.rparen, message: "Expected a closing parenthesis after method parameters.")
        
        try consume(.endOfLine, message: "Expected a new line after foreign method declaration.")
        
        return try ForeignMethodDeclStmt(className: className, identifier: identifier, isSetter: isSetter, isStatic: isStatic, parameters: parameters)
    }
    
    /// Parses a `for` loop.
    /// Assumes we've just consumed the `for` keyword.
    ///
    /// Syntax:
    ///
    /// ```objo
    /// for (initialiser?; condition?; incrementExpression?) {
    ///  statements
    /// }
    /// ```
    private func forStatement() throws -> ForStmt {
        let forKeyword = _previous!
        
        try consume(.lparen, message: "Expected an opening parenthesis after the `for` keyword.")
        
        var initialiser: Stmt?
        if match(.semicolon) {
            // No initialiser.
        } else if match(.var_) {
            // Variable declaration.
            initialiser = try varDeclaration(terminator: .semicolon)
        } else {
            // Just an expression.
            initialiser = try expressionStatement(terminator: .semicolon)
        }
        
        // Optional condition to exit the loop.
        var condition: Expr?
        if !match(.semicolon) {
            condition = try expression()
            try consume(.semicolon, message: "Expected a semicolon after the loop condition.")
        }
        
        // Optional increment expression.
        var increment: Expr?
        if !match(.rparen) {
            increment = try expression()
            try consume(.rparen, message: "Expected a closing parenthesis after the loop's increment expression.")
        }
        
        ditch(.endOfLine)
        
        try consume(.lcurly, message: "Expected an opening curly brace after the `for` clauses.")
        
        return ForStmt(initialiser: initialiser, condition: condition, increment: increment, body: try block(), forKeyword: forKeyword)
    }
    
    /// Parses a function declaration.
    /// Assumes the parser has just consumed the `function` keyword.
    private func functionDeclaration() throws -> FunctionDeclStmt {
        let funcKeyword = _previous!
        
        // Get the name of the function.
        let name = try fetch(.identifier, message: "Expected a function name. It must begin with a lowercase letter.")
        
        try consume(.lparen, message: "Expected an opening parenthesis after the function's name.")
        
        // Optional parameters.
        var params: [Token] = []
        if !check(.rparen) {
            repeat {
                params.append(try fetch(.identifier, message: "Expected parameter name."))
            } while !match(.comma)
        }
        
        try consume(.rparen, message: "Expected a closing parenthesis after the function parameters.")
        
        try consume(.lcurly, message: "Expected an opening curly brace after the function's parameters.")
    
        let body = try block()
        
        return FunctionDeclStmt(name: name, parameters: params, body: body, funcKeyword: funcKeyword)
    }
    
    /// Returns the grammar rule (if one exists) for the passed token.
    private func getRule(type: TokenType) -> GrammarRule? {
        return Parser.rules[type]
    }
    
    /// Parses an `if` statement. Assumes the parser has just consumed the `if` token.
    private func ifStatement() throws -> IfStmt {
        let ifKeyword = _previous!
        
        let condition = try expression()
        
        // Parse the "then" branch.
        var thenBranch: Stmt?
        if match(.then) {
            // Single line "if".
            thenBranch = try statement()
        } else if match(.lcurly) {
            thenBranch = try block()
        } else {
            try error(message: "Expected `then` or an opening curly brace after the condition.")
        }
        
        // Optional else statement.
        var elseBranch: Stmt?
        if match(.else_) {
            if match(.if_) {
                elseBranch = try ifStatement()
            } else if match(.lcurly) {
                elseBranch = try block()
            } else {
                try error(message: "Expected an opening curly brace or another `if` statement after the `if` keyword.")
            }
        }
        
        return IfStmt(condition: condition, thenBranch: thenBranch!, elseBranch: elseBranch, ifKeyword: ifKeyword)
    }
    
    /// Parses a class method declaration (instance or static).
    ///
    /// There are two types of methods: regular and setters.
    /// Regular methods may or may not return values and can accept any number of arguments.
    /// Setters do not return a value and must have one argument. Format:
    /// ```
    /// age=(value){} # Note the `=` to denote it's a setter.
    /// ```
    /// If `isStatic` is `true` then this is a static method declaration.
    private func methodDeclaration(className: String, isStatic: Bool) throws -> MethodDeclStmt {
        // Handle operators differently.
        if match(Parser.overloadableOperators) {
            return try overloadedOperator(className: className, op: _previous!, isStatic: isStatic, isForeign: false) as! MethodDeclStmt
        }
        
        let identifier = try fetch(.identifier)
        
        let isSetter = match(.equal)
        
        // Optional parameters.
        var parameters: [Token] = []
        var hasParens = false
        if match(.lparen) {
            hasParens = true
            if !check(.rparen) {
                repeat {
                    parameters.append(try fetch(.identifier, message: "Expected parameter name."))
                } while !match(.comma)
            }
        }
        
        if isSetter && parameters.count != 1 {
            try error(message: "Setters must have exactly one parameter.", location: identifier)
        }
        
        if hasParens {
            try consume(.rparen, message: "Expected a closing parenthesis after the method parameters")
        }
        
        try consume(.lcurly, message: "Expected an opening curly brace after method parameters.")
        
        return try MethodDeclStmt(className: className, identifier: identifier, isSetter: isSetter, isStatic: isStatic, parameters: parameters, body: try block())
    }
    
    /// Parses an overloaded operator `op`. Returns either a `MethodDeclStmt` or a `ForeignMethodDeclStmt`.
    ///
    /// Assumes `op` is an overloadable operator.
    /// Assumes the last consumed token is the operator to overload.
    /// Examples:
    /// ```
    /// -() {body} // prefix (i.e. unary) `-`
    /// +(a) {body} // infix `+`
    /// [a] {body} // single index subscript getter
    /// [a, b] {body} // multi-index subscript getter
    /// [a]=(value) // single index subscript setter
    /// [a, b]=(value) // single index subscript setter
    /// ```
    /// Note: foreign methods do not have a body.
    private func overloadedOperator(className: String, op: Token, isStatic: Bool, isForeign: Bool) throws -> Stmt {
        // Every declaration needs an opening parenthesis after the operator *except* subscripts.
        if op.type != .lsquare {
            try consume(.lparen, message: "Expected an opening parenthesis after the overloaded operator.")
        }
        
        // Parameter(s).
        var parameters: [Token] = []
        if !check(.rparen) {
            repeat {
                parameters.append(try fetch(.identifier, message: "Expected a parameter name."))
            } while !match(.comma)
        }
        
        // Closer after parameter/index(es).
        if op.type == .lsquare {
            try consume(.rsquare, message: "Expected a closing square bracket after indexes.")
        } else {
            try consume(.rparen, message: "Expected a closing parenthesis after method parameters.")
        }
        
        // Subscript setter?
        // The value to assign becomes the last parameter.
        var isSetter = false
        if match(.equal) {
            // Must have at least one parameter already.
            if parameters.count == 0 {
                try error(message: "Subscript setters require at least one index after the opening square bracket.")
            }
            
            if op.type == .lsquare {
                isSetter = true
                try consume(.lparen, message: "Expected an opening parenthesis after `=`.")
                parameters.append(try fetch(.identifier))
                try consume(.rparen, message: "Expected a closing parenthesis after the value to assign to overloaded subscript setter.")
            } else {
                try error(message: "Unexpected `=` token. Only overloaded subscript operators may be setters.")
            }
        }
        
        // Check the correct number of parameters have been specified.
        if parameters.count == 0 {
            // Only overloadable unary operators may have zero parameters.
            if Parser.overloadableUnaryOperators.contains(op.type) {
                try error(message: "`\(op.type)` is not an overloadable unary operator.")
            }
        } else if parameters.count > 1 && op.type != .lsquare {
            try error(message: "Only subscript methods may have more than one parameter.")
        }
        
        if isForeign {
            // Foreign methods don't have a body so we're done.
            return try ForeignMethodDeclStmt(className: className, identifier: op, isSetter: isSetter, isStatic: isStatic, parameters: parameters)
        } else {
            // Consume the method's body.
            try consume(.lcurly, message: "Expected an opening curly brace after method parameters.")
            return try MethodDeclStmt(className: className, identifier: op, isSetter: isSetter, isStatic: isStatic, parameters: parameters, body: try block())
        }
    }
    
    /// Puts the parser into panic mode.
    ///
    /// We try to put the parser back into a usable state once it has encountered an error.
    /// This allows the parser to keep parsing even though an error has occurred without causing
    /// all subsequent code to be misinterpreted.
    ///
    /// `error` contains details of the error that triggered panic mode.
    private func panic(_ error: ParserError) {
        // Add this to our array of errors already encountered.
        _errors.append(error)
        
        // Try to recover.
        synchronise()
    }
    
    /// Parses a `return` statement.
    /// Assumes the parser has just consumed the `return` keyword.
    private func returnStatement() throws -> ReturnStmt {
        let keyword = _previous!
        
        var value: Expr?
        if match(.endOfLine, .eof) {
            value = NothingLiteral(token: keyword)
        } else {
            value = try expression()
            if !check(.rcurly) {
                try consume(.endOfLine, message: "Expected a new line or closing curly brace after the return statement value.")
            }
        }
        
        return ReturnStmt(keyword: keyword, value: value)
    }
    
    /// Parses a statement.
    private func statement() throws -> Stmt {
        // TODO: Implement the remaining statements.
        if match(.lcurly) {
        
            return try block()
            
        } else if match(.if_) {
            
            return try ifStatement()
            
        } else if match(.while_) {
          
            return try whileStatement()
            
        } else if match(.for_) {
            
            return try forStatement()
            
        } else if match(.foreach) {
            
            return try foreachStatement()
            
        } else if match(.assert) {
            
            return try assertStatement()
            
        } else if match(.return_) {
            
            return try returnStatement()
            
        } else if match(.exit) {
            
            return try exitStatement()
            
        } else if match(.continue_) {
            
            return try continueStatement()
            
        } else if match(.breakpoint) {
            
            return try breakpointStatement()
            
        } else if match(.switch_) {
            
            return try switchStatement()
            
        } else {
            
            return try expressionStatement()
            
        }
    }
    
    /// Parses a `switch` statement. Assumes the parser has just consumed the `switch` token.
    ///
    /// ```
    /// switch consider {
    ///  case value1 {}
    ///  case value2, value3 {}
    ///  else {}
    /// }
    /// ```
    private func switchStatement() throws -> SwitchStmt {
        let switchKeyword = _previous!
        
        let consider = try expression()
        
        ditch(.endOfLine)
        
        try consume(.lcurly, message: "Expected an opening curly brace after the switch expression to consider.")
        
        var cases: [CaseStmt] = []
        while match(.case_) {
            let caseKeyword = _previous!
            
            // Get this case's value(s).
            var values: [Expr] = []
            repeat {
                values.append(try expression())
            } while !match(.comma)
            
            ditch(.endOfLine)
            
            try consume(.lcurly, message: "Expected a block after the case's value(s).")
            
            let body = try block()
            
            ditch(.endOfLine)
            
            cases.append(CaseStmt(values: values, body: body, keyword: caseKeyword))
        }
        
        // Optional `else` case.
        var elseCase: ElseCaseStmt?
        if match(.else_) {
            let elseKeyword = _previous!
            
            ditch(.endOfLine)
            
            try consume(.lcurly, message: "Expected an opening curly brace after the `else` keyword.")
            
            elseCase = ElseCaseStmt(body: try block(), keyword: elseKeyword)
        }
        
        ditch(.endOfLine)
        
        try consume(.rcurly, message: "Expected a closing curly brace after the final switch case.")
        
        return SwitchStmt(consider: consider, cases: cases, elseCase: elseCase, keyword: switchKeyword)
    }
    
    /// Called when the parser enters panic mode.
    /// Tries to get the parser back to a state where it can continue parsing.
    ///
    /// We do this by discarding tokens until we hit a statement boundary.
    private func synchronise() {
        if atEnd() { return }
        
        advance()
        
        while !atEnd() {
            switch _current?.type {
            case .class_, .function:
                // Hopefully we're synchronised now.
                return
                
            default:
                advance()
            }
        }
    }
    
    /// Parses a variable declaration. Assumes the parser has just consumed the `var` keyword.
    /// `terminator` will be consumed.
    ///
    /// Format:
    /// ```objo
    /// VAR IDENTIFIER (EQUAL expression)?
    /// ```
    ///
    /// If an initialiser expression is not provided then the variable is initialised to `nothing`.
    /// `terminator` is the token that is required to occur after the declaration to be valid.
    private func varDeclaration(terminator: TokenType = .endOfLine) throws -> VarDeclStmt {
        let varLocation = _previous!
        
        // The next token should be an identifier.
        let identifier = try fetch(.identifier, message: "Expected a variable name. Remember, variable names must begin with a lowercase letter.")
        
        // Has an initialiser optionally been specified?
        var initialiser: Expr = NothingLiteral(token: varLocation)
        if match(.equal) { initialiser = try expression() }
        
        // Most variable declarations expect a new line after them but some (such as within a
        // `for` loop initialiser) require something else (e.g. a semicolon).
        if terminator == .endOfLine || terminator == .eof {
            try consume(.endOfLine, .eof, message: "Expected a new line or EOF after a variable declaration")
        } else {
            try consume(terminator, message: "Expected a \(terminator) after a variable declaration.")
        }
        
        return VarDeclStmt(identifier: identifier, initialiser: initialiser, location: varLocation)
    }
    
    /// Parses a `while` statement.
    /// Assumes the `while` token has just been consumed.
    private func whileStatement() throws -> WhileStmt {
        let whileKeyword = _previous!
        
        let condition = try expression()
        
        ditch(.endOfLine)
        
        try consume(.lcurly, message: "Expected an opening parenthesis after the `while` condition.")
        
        return WhileStmt(condition: condition, body: try block(), whileKeyword: whileKeyword)
    }
}
