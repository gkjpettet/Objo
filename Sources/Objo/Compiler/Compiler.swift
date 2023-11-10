//
//  Compiler.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

import Foundation

public class Compiler: ExprVisitor, StmtVisitor {
        
    // MARK: - Class constants
    
    /// The script ID value the compiler uses for the core library.
    public static let CORE_LIBRARY_SCRIPT_ID: Int = -1
    
    /// The script ID used by the compiler for the synthetic opening and closing braces around the `*main*` function.
    public static let MAIN_SCRIPT_ID = -2
    
    /// The maximum number of local variables that can be in scope at one time.
    /// Limited to one byte due to the instruction's operand size.
    private static let MAX_LOCALS = 256
    
    // MARK: - Private properties
    
    /// The abstract syntax tree this compiler is compiling.
    private var ast: [Stmt] = []
    
    /// The time take for the last compilation took.
    private var compileTime: TimeInterval?
    
    /// The core library source code.
    private var coreLibrarySource: String
    
    /// Optional data about the class currently being compiled. Will be nil if the compiler isn't currently compiling a class.
    private var currentClass: ClassData?
    
    private var currentChunk: Chunk {
        get { return self.function!.chunk }
        set(newValue) { self.function!.chunk = newValue }
    }
    
    /// The token the compiler is currently compiling.
    private var currentLocation: Token?
    
    /// The current innermost loop being compiled, or `nil` if not in a loop.
    private var currentLoop: LoopData?
    
    /// If `true` then the compiler will output debug-quality bytecode.
    private var debugMode: Bool = false
    
    /// `true` if this compiler is compiling a static method.
    private var isStaticMethod = false
    
    /// Contains the names of every global variable declared as the key. Only the outermost compiler keeps track of declared variables. Child compilers, add new globals to the outermost parent. Therefore this may be empty even if there are known globals.
    /// Key = global name, Value = Bool (unused, set to `false`).
    private(set) var knownGlobals: [String : Bool] = [:]
    
    /// The classes already compiled by the compiler. Key = class name.
    private(set) var knownClasses: [String : ClassData] = [:]
    
    /// The local variables that are in scope.
    private(set) var locals: [LocalVariable] = []
    
    /// This compiler's internal parser.
    private var parser: Parser = Parser()
    
    /// The time taken for the last parsing phase.
    private var parseTime: TimeInterval?
    
    /// The current scope depth. 0 = global scope.
    private var scopeDepth: Int = 0
    
    /// Used to track the compilation time.
    private var stopWatch: Stopwatch = Stopwatch()
    
    /// This compiler's internal lexer.
    private var tokeniser: Tokeniser = Tokeniser()
    
    /// The time taken for the last tokenising phase.
    private var tokeniseTime: TimeInterval?
    
    /// The tokens this compiler is compiling. May be empty if the compiler was instructed to compile an AST directly.
    private var tokens: [Token] = []
    
    // MARK: - Public properties
    
    /// This compiler's optional enclosing compiler. Needed as compilers can call other compilers to compile functions, methods, etc.
    public var enclosing: Compiler?
    
    /// The function currently being compiled.
    public var function: Function?
    
    /// If `true` then the compiler will try to optimise code where possible.
    public var optimise: Bool = true
    
    /// The outermost compiler. This is the compiler compiling the main function. It may be **this** compiler.
    public var outermostCompiler: Compiler {
        var outermost = self
        while outermost.enclosing != nil {
            outermost = outermost.enclosing!
        }
        return outermost
    }
    
    /// The type of function currently being compiled.
    public var type: FunctionType = .topLevel
    
    // MARK: - Initialiser
    
    /// Instantiates a new compiler.
    /// `coreLibrarySource` is the source code for the core library.
    /// This will be compiled before any user source code.
    public init(coreLibrarySource: String) {
        self.coreLibrarySource = coreLibrarySource
    }
    
    // MARK: - Public methods
    
    /// Compiles and returns a function. May throw a `CompilerError`.
    ///
    /// - Parameters:
    ///     - name: The name of the function.
    ///     - parameters: If this function accepts parameters then this is an array of their identifiers.
    ///     - body: The function's body of statements as a block.
    ///     - type: The type of function to compile.
    ///     - currentClass: Data about the class currently being compiled. Will be nil if the compiler isn't currently compiling a class.
    ///     - isStaticMethod: `true` if the compiler is compiling a static method.
    ///     - debugMode: If `true` then the compiler will include additional debugging information in compiled chunks. Debg chunks are less performant than production chunks.
    ///     - shouldReset: If `true` then the compiler will be reset prior to compiling this function.
    ///     - enclosingCompiler: This compiler's optional enclosing compiler. Exists as compilers can call other compilers to compile functions, methods, etc.
    public func compile(name: String, parameters: [Token], body: BlockStmt, type: FunctionType, currentClass: ClassData?, isStaticMethod: Bool, debugMode: Bool, shouldReset: Bool, enclosingCompiler: Compiler?) throws -> Function {
        if shouldReset { reset() }
        
        // Time how long the process takes.
        stopWatch.start()
        
        // Should the compiler produce debug or production quality bytecode?
        self.debugMode = debugMode
        
        self.currentClass = currentClass
        self.enclosing = enclosingCompiler
        self.type = type
        self.isStaticMethod = isStaticMethod
        
        // Create a new function to compile into.
        function = try Function(name: name, parameters: parameters, isSetter: false, debugMode: debugMode)
        
        if self.type != .topLevel {
            beginScope()
            
            // Compile the parameters.
            if parameters.count > 255 {
                try error(message: "Functions cannot have more than 255 parameters.")
            }
            
            for param in parameters {
                try declareVariable(identifier: param, initialised: false, trackAsGlobal: false)
                try defineVariable(index: 0) // The index value doesn't matter as the parameters are local.
            }
        }
        
        // Compile the function's body.
        for stmt in body.statements {
            try stmt.accept(self)
        }
        
        // Determine the end location for this AST.
        let endLocation: Token
        if body.statements.count == 0 {
            // Synthesise a fake end location token.
            endLocation = BaseToken(type: .eof, start: 0, line: 1, lexeme: nil, scriptId: body.closingBrace.scriptId)
        } else if body.statements.last! is BlockStmt {
            endLocation = (body.statements.last! as! BlockStmt).closingBrace
        } else {
            endLocation = body.statements.last!.location
        }
        
        // Wind down the compiler.
        endCompiler(location: endLocation)
        
        // Stop timing.
        stopWatch.stop()
        compileTime = stopWatch.elapsedTime()
        
        return function!
    }
    
    /// Compiles raw Objo source code into a top level function.
    /// Prepends the code with the core library source code provide during this compiler's instantiation.
    ///
    /// - Throws `TokeniserError` if an error occurs during tokenisation.
    /// - Throws `ParserError` if a parsing error occurs.
    /// - Throws `CompilerError` if a compiling error occurs.
    public func compile(source: String, debugMode: Bool, scriptID: Int) throws -> Function {
        reset()
        
        self.debugMode = debugMode
        
        // Import and tokenise the core libraries first.
        if coreLibrarySource != "" {
            tokens = try tokeniser.tokenise(source: coreLibrarySource, scriptId: Compiler.CORE_LIBRARY_SCRIPT_ID, includeEOF: false)
        }
        
        // Tokenise the user's source code. This may throw a TokeniserError, therefore aborting compilation.
        stopWatch.start()
        let userTokens: [Token] = try tokeniser.tokenise(source: source, scriptId: scriptID)
        stopWatch.stop()
        tokeniseTime = stopWatch.elapsedTime()
        
        // Append the user's tokens to the core tokens.
        tokens.append(contentsOf: userTokens)
        
        // Parse.
        stopWatch.reset()
        stopWatch.start()
        ast = parser.parse(tokens: tokens)
        stopWatch.stop()
        parseTime = stopWatch.elapsedTime()
        
        if parser.hasError {
            var message = ""
            if parser.errors.count == 1 {
                message = parser.errors[0].message
            } else {
                message = "\(parser.errors.count) parsing errors occurred."
            }
            throw ParserError(message: message, location: parser.errors[0].location)
        }
        
        // Compile the top level `*main*` function.
        // Synthesise tokens for the opening and closing curly braces.
        let openingBrace = BaseToken(type: .lcurly, start: 0, line: 0, lexeme: nil, scriptId: Compiler.MAIN_SCRIPT_ID)
        let closingBrace = BaseToken(type: .rcurly, start: 0, line: 0, lexeme: nil, scriptId: Compiler.MAIN_SCRIPT_ID)
        
        // The `*main*` function has no parameters.
        let mainParams: [Token] = []
        
        // Synthesise the main function's body.
        let mainBody = BlockStmt(statements: ast, openingBrace: openingBrace, closingBrace: closingBrace)
        
        // Compile and return the function.
        return try compile(name: "*main*", parameters: mainParams, body: mainBody, type: .topLevel, currentClass: nil, isStaticMethod: false, debugMode: debugMode, shouldReset: false, enclosingCompiler: nil)
    }
    
    /// Resets the compiler so it's ready to compile again.
    public func reset() {
        tokeniser = Tokeniser()
        tokens = []
        tokeniseTime = 0
        
        parser = Parser()
        ast = []
        parseTime = 0
        
        stopWatch.reset()
        compileTime = 0
        
        scopeDepth = 0
        
        // Locals
        locals = []
        // Claim slot 0 in the stack for the VM's internal use.
        // For methods and constructors it will be `this`.
        let name: String? = (type == .method || type == .constructor ? "this" : nil)
        let synthetic = BaseToken(type: .identifier, start: 0, line: 1, lexeme: name, scriptId: -1)
        locals.append(LocalVariable(identifier: synthetic, depth: 0))
        
        currentLoop = nil
        currentClass = nil
        knownClasses = [:]
        enclosing = nil
        knownGlobals = [:]
    }
    
    // MARK: - Private methods
    
    /// Tracks the existence of a global variable named `name`.
    private func addGlobal(name: String) {
        // Only the outermost compiler stores the names of defined globals.
        outermostCompiler.knownGlobals[name] = false
    }
    
    /// Tracks a local variable in the current scope.
    private func addLocal(identifier: Token, initialised: Bool = false) throws {
        if locals.count >= Compiler.MAX_LOCALS {
            try error(message: "Too many local variables in scope.")
        }
        
        // Set the local's depth to `-1` if not yet initialised.
        locals.append(LocalVariable(identifier: identifier, depth: initialised ? scopeDepth : -1))
    }
    
    /// Begins a new scope.
    private func beginScope() {
        scopeDepth += 1
    }
    
    /// For local variables, this is the point at which the compiler records their existence.
    ///
    /// - Parameters:
    ///     - identifier: The token representing the variable's name in the original source code.
    ///     - initialised: If `true` then the compiler marks the local as initialised immediately (relevant for functions).
    ///     - trackAsGlobal: If `true` then this variable is a global variable (cannot be shadowed).
    private func declareVariable(identifier: Token, initialised: Bool, trackAsGlobal: Bool) throws {
        currentLocation = identifier
        
        if trackAsGlobal {
            if globalExists(name: identifier.lexeme!) {
                try error(message: "Redefined global identifier `\(identifier.lexeme!)`.")
            } else {
                addGlobal(name: identifier.lexeme!)
            }
        }
        
        // If this is a global variable we're now done.
        if scopeDepth == 0 { return }
        
        // Ensure that another variable has not been declared in current scope with this name.
        let name = identifier.lexeme!
        for local in locals.reversed() {
            if local.depth != -1 && local.depth < scopeDepth {
                break
            }
            
            if name == local.name {
                try error(message: "Redefined variable `\(name)`.")
            }
        }
        
        // Must be a local variable. Add it to the list of variables in the current scope.
        try addLocal(identifier: identifier, initialised: initialised)
    }
    
    /// Defines a variable as ready to use.
    ///
    /// For globals it outputs the instructions required to define a global variable whose name is stored in the
    /// constant pool at `index`.
    /// For locals, it marks the variable as ready for use by setting its `depth` property to the current scope depth.
    private func defineVariable(index: Int) throws {
        if scopeDepth > 0 {
            // Local variable definition.
            if locals.count > 0 {
                locals[locals.count - 1].depth = scopeDepth
            }
        } else {
            // Global variable definition.
            try emitVariableOpcode(shortOpcode: .defineGlobal, longOpcode: .defineGlobalLong, operand: index)
        }
    }
    
    /// Appends an opcode (UInt8) to the current chunk at the current location.
    /// An optional `location` can be provided otherwise the compiler defaults to its current location.
    private func emitOpcode(_ opcode: Opcode, location: Token? = nil) {
        currentChunk.writeOpcode(opcode, token: location ?? currentLocation!)
    }
    
    /// Appends an opcode (UInt8) and an 8-bit operand to the current chunk at the current location.
    /// An optional `location` can be provided otherwise the compiler defaults to its current location.
    /// Assumes `operand` can be represented by a single byte.
    private func emitOpcode8(opcode: Opcode, operand: UInt8, location: Token? = nil) {
        let loc: Token = location ?? currentLocation!
        currentChunk.writeOpcode(opcode, token: loc)
        currentChunk.writeByte(operand, token: loc)
    }
    
    /// Appends an opcode (UInt8) and a 16-bit operand to the current chunk at the current location.
    /// An optional `location` can be provided otherwise the compiler defaults to its current location.
    /// Assumes `operand` can fit within two bytes.
    private func emitOpcode16(opcode: Opcode, operand: UInt16, location: Token? = nil) {
        emitOpcode(opcode, location: location ?? currentLocation)
        emitUInt16(value: operand, location: location ?? currentLocation)
    }
    
    /// Emits a return instruction, defaulting to returning `nothing` on function returns.
    /// Defaults to the current location.
    private func emitReturn(location: Token? = nil) {
        if self.type == .constructor {
            // Rather than return `nothing`, constructors must default to
            // returning `this` which will be in slot 0 of the call frame.
            emitOpcode8(opcode: .getLocal, operand: 0, location: location)
        } else {
            emitOpcode(.nothing, location: location)
        }
        
        emitOpcode(.return_, location: location)
    }
    
    /// Appends an unsigned integer (big endian format, most significant byte first) to the current chunk.
    /// The current location is used unless otherwise specified.
    private func emitUInt16(value: UInt16, location: Token? = nil) {
        currentChunk.writeUInt16(value, token: location ?? currentLocation!)
    }
    
    /// Emits an opcode followed by `operand`. `
    /// The operand may by one or two bytes in length. If `operand` is one byte then `shortOpcode` is emitted before the operand, otherwise `longOpcode` is emitted.
    /// If `index <= 255` then `shortOpcode` is emitted followed by the single byte `index`.
    /// Otherwise `longOpcode` is emitted followed by the two byte `index`.
    private func emitVariableOpcode(shortOpcode: Opcode, longOpcode: Opcode, operand: Int, location: Token? = nil) throws {
        if operand < 0 || operand > Chunk.MAX_CONSTANTS {
            try error(message: "The operand is out of range. Expected `0 <= operand \(Chunk.MAX_CONSTANTS)`.", location: location ?? currentLocation)
        }
        
        if operand <= 255 {
            // We only need a single byte operand.
            emitOpcode8(opcode: shortOpcode, operand: UInt8(operand), location: location ?? currentLocation)
        } else {
            // We need two bytes for the operand.
            emitOpcode16(opcode: longOpcode, operand: UInt16(operand), location: location ?? currentLocation)
        }
    }
    
    /// Internally called when the compiler is finished.
    /// The compiler needs to implictly return an appropriate value if the user did not explictly specify one.
    private func endCompiler(location: Token) {
        if function!.chunk.code.count == 0 {
            
            // We've just compiled an empty function.
            emitReturn(location: location)
            
        } else if function!.chunk.code.last! != Opcode.return_.rawValue {
            
            // The function's last instruction was *not* a return statement.
            emitReturn(location: location)
            
        }
    }
    
    /// Throws a `CompilerError` at the current location.
    /// If the error is not at the current location, `location` may be passed instead.
    private func error(message: String, location: Token? = nil) throws {
        throw CompilerError(message: message, location: location ?? currentLocation)
    }
    
    /// Returns `true` if a global variable named `name` has already been defined by this compiler chain.
    private func globalExists(name: String) -> Bool {
        return outermostCompiler.knownGlobals[name] != nil
    }
    
    /// Performs a binary operation on two numeric literals, `left` and `right` and tells
    /// the VM to put the result on the stack.
    ///
    /// This is an optimisation for binary operators where both operands are known in
    /// advance to be numeric literals.
    private func optimisedBinary(op: TokenType, left: Double, right: Double) throws {
        // First we do the appropriate calculation and then add that to the chunk's constant table,
        // getting the index of this value in the constant table.
        // Then we tell the VM to produce that value by supplying it with the index in the table.
        switch op {
        case .plus:
            let index = currentChunk.addConstant(.number(left + right))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .minus:
            let index = currentChunk.addConstant(.number(left - right))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .forwardSlash:
            let index = currentChunk.addConstant(.number(left / right))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .star:
            let index = currentChunk.addConstant(.number(left * right))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .percent:
            let index = currentChunk.addConstant(.number(left.truncatingRemainder(dividingBy: right)))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .less:
            emitOpcode(left < right ? .true_ : .false_)
            
        case .lessEqual:
            emitOpcode(left <= right ? .true_ : .false_)
            
        case .greater:
            emitOpcode(left > right ? .true_ : .false_)
            
        case .greaterEqual:
            emitOpcode(left >= right ? .true_: .false_)
            
        case .equalEqual:
            emitOpcode(left == right ? .true_ : .false_)
            
        case .notEqual:
            emitOpcode(left != right ? .true_ : .false_)
            
        case .lessLess:
            let result = Double(Int(left) << Int(right))
            let index = currentChunk.addConstant(.number(result))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .greaterGreater:
            let result = Double(Int(left) >> Int(right))
            let index = currentChunk.addConstant(.number(result))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .ampersand:
            let result = Double(UInt32(left) & UInt32(right))
            let index = currentChunk.addConstant(.number(result))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .caret:
            let result = Double(UInt32(left) ^ UInt32(right))
            let index = currentChunk.addConstant(.number(result))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        case .pipe:
            let result = Double(UInt32(left) | UInt32(right))
            let index = currentChunk.addConstant(.number(result))
            try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            
        default:
            try error(message: "Unknown binary operator \"\(op)\".")
        }
    }
    
    // MARK: - `ExprVisitor` protocol methods
    
    public func visitAssignment(expr: AssignmentExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling assignment is not yet implemented", location: expr.location)
    }
    
    public func visitBareInvocation(expr: BareInvocationExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling bare invocations is not yet implemented", location: expr.location)
    }
    
    public func visitBareSuperInvocation(expr: BareSuperInvocationExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling bare super invocations is not yet implemented", location: expr.location)
    }
    
    /// Compiles a binary expression.
    ///
    /// `a OP b` becomes:
    /// ```
    /// OP
    /// b   ← top of the stack
    /// a
    /// ```
    public func visitBinary(expr: BinaryExpr) throws {
        currentLocation = expr.location
        
        if optimise {
            // If both operands are numeric literals, we can do the arithmetic upfront
            // and just tell the VM to produce the result.
            if expr.left is NumberLiteral && expr.right is NumberLiteral {
                try optimisedBinary(op: expr.op.type, left: (expr.left as! NumberLiteral).value, right: (expr.right as! NumberLiteral).value)
                return
            }
        }
        
        // Compile the left and right operands to put them on the stack.
        try expr.left.accept(self)  // a
        try expr.right.accept(self) // b
        
        // Emit the correct opcode for the binary operator.
        switch expr.op.type {
        case .plus:
            emitOpcode(.add)
            
        case .minus:
            emitOpcode(.subtract)
            
        case .forwardSlash:
            emitOpcode(.divide)
            
        case .star:
            emitOpcode(.multiply)
            
        case .percent:
            emitOpcode(.modulo)
            
        case .less:
            emitOpcode(.less)
            
        case .lessEqual:
            emitOpcode(.lessEqual)
            
        case .greater:
            emitOpcode(.greater)
            
        case .greaterEqual:
            emitOpcode(.greaterEqual)
            
        case .equalEqual:
            emitOpcode(.equal)
            
        case .notEqual:
            emitOpcode(.notEqual)
            
        case .lessLess:
            emitOpcode(.shiftLeft)
            
        case .greaterGreater:
            emitOpcode(.shiftRight)
            
        case .ampersand:
            emitOpcode(.bitwiseAnd)
            
        case .caret:
            emitOpcode(.bitwiseXor)
            
        case .pipe:
            emitOpcode(.bitwiseOr)
            
        default:
            try error(message: "Unknown binary operator \"\(expr.op.type)\"")
        }
    }
    
    /// The VM should produce a boolean constant.
    public func visitBoolean(expr: BooleanLiteral) throws {
        currentLocation = expr.location
        
        emitOpcode(expr.value ? .true_ : .false_)
    }
    
    public func visitCall(expr: CallExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling call expressions is not yet implemented", location: expr.location)
    }
    
    public func visitClass(expr: ClassExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling class expressions is not yet implemented", location: expr.location)
    }
    
    public func visitField(expr: FieldExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling field access is not yet implemented", location: expr.location)
    }
    
    public func visitFieldAssignment(expr: FieldAssignmentExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling field assignment is not yet implemented", location: expr.location)
    }
    
    public func visitKeyValue(expr: KeyValueExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling key-value expressions is not yet implemented", location: expr.location)
    }
    
    public func visitListLiteral(expr: ListLiteral) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling list literals is not yet implemented", location: expr.location)
    }
    
    public func visitLogical(expr: LogicalExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling logical expressions is not yet implemented", location: expr.location)
    }
    
    public func visitMethodInvocation(expr: MethodInvocationExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling method invocations is not yet implemented", location: expr.location)
    }
    
    public func visitIs(expr: IsExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `is` expressions is not yet implemented", location: expr.location)
    }
    
    public func visitMapLiteral(expr: MapLiteral) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling map literals is not yet implemented", location: expr.location)
    }
    
    public func visitNothing(expr: NothingLiteral) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `nothing` literals` is not yet implemented", location: expr.location)
    }
    
    public func visitNumber(expr: NumberLiteral) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling number literals is not yet implemented", location: expr.location)
    }
    
    public func visitPostfix(expr: PostfixExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling postfix expressions is not yet implemented", location: expr.location)
    }
    
    public func visitRange(expr: RangeExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling range expressions is not yet implemented", location: expr.location)
    }
    
    public func visitStaticField(expr: StaticFieldExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling static field access is not yet implemented", location: expr.location)
    }
    
    public func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling static field assignment is not yet implemented", location: expr.location)
    }
    
    public func visitString(expr: StringLiteral) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling string literals is not yet implemented", location: expr.location)
    }
    
    public func visitSubscript(expr: SubscriptExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling subscript expressions is not yet implemented", location: expr.location)
    }
    
    public func visitSubscriptSetter(expr: SubscriptSetterExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling subscript setter expressions is not yet implemented", location: expr.location)
    }
    
    public func visitSuperMethodInvocation(expr: SuperMethodInvocationExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling super method invocations is not yet implemented", location: expr.location)
    }
    
    public func visitSuperSetter(expr: SuperSetterExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling super setter expressions is not yet implemented", location: expr.location)
    }
    
    public func visitTernary(expr: TernaryExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling ternary expressions is not yet implemented", location: expr.location)
    }
    
    public func visitThis(expr: ThisExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling this expressions is not yet implemented", location: expr.location)
    }
    
    public func visitUnary(expr: UnaryExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling unary expressions is not yet implemented", location: expr.location)
    }
    
    public func visitVariable(expr: VariableExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling variable access is not yet implemented", location: expr.location)
    }
    
    // MARK: - `StmtVisitor` protocol methods
    
    public func visitAssertStmt(stmt: AssertStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling assert statements is not yet implemented", location: stmt.location)
    }
    
    public func visitBlock(stmt: BlockStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling blocks is not yet implemented", location: stmt.location)
    }
    
    public func visitBreakpoint(stmt: BreakpointStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling breakpoints is not yet implemented", location: stmt.location)
    }
    
    public func visitCase(stmt: CaseStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling case statements is not yet implemented", location: stmt.location)
    }
    
    public func visitClassDeclaration(stmt: ClassDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling class declarations is not yet implemented", location: stmt.location)
    }
    
    public func visitConstructorDeclaration(stmt: ConstructorDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling constructors is not yet implemented", location: stmt.location)
    }
    
    public func visitContinue(stmt: ContinueStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling continue statements is not yet implemented", location: stmt.location)
    }
    
    public func visitDo(stmt: DoStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `do` statements is not yet implemented", location: stmt.location)
    }
    
    public func visitElseCase(stmt: ElseCaseStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling else cases is not yet implemented", location: stmt.location)
    }
    
    public func visitExit(stmt: ExitStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling exit statements is not yet implemented", location: stmt.location)
    }
    
    /// Compiles an expression statement.
    public func visitExpressionStmt(stmt: ExpressionStmt) throws {
        currentLocation = stmt.location
        
        // Compile the expression.
        try stmt.expression.accept(self)
        
        // An expression statement evaluates the expression and, importantly, **discards the result**.
        emitOpcode(.pop)
    }
    
    public func visitFor(stmt: ForStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `for` statements is not yet implemented", location: stmt.location)
    }
    
    public func visitForEach(stmt: ForEachStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `foreach` statements is not yet implemented", location: stmt.location)
    }
    
    public func visitForeignMethodDeclaration(stmt: ForeignMethodDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling foreign method declarations is not yet implemented", location: stmt.location)
    }
    
    public func visitFuncDeclaration(stmt: FunctionDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling function declarations is not yet implemented", location: stmt.location)
    }
    
    public func visitIf(stmt: IfStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling `if` statements is not yet implemented", location: stmt.location)
    }
    
    public func visitMethodDeclaration(stmt: MethodDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling method declarations is not yet implemented", location: stmt.location)
    }
    
    public func visitReturn(stmt: ReturnStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling return statements is not yet implemented", location: stmt.location)
    }
    
    public func visitSwitch(stmt: SwitchStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling switch statements is not yet implemented", location: stmt.location)
    }
    
    public func visitVarDeclaration(stmt: VarDeclStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling variable declarations is not yet implemented", location: stmt.location)
    }
    
    public func visitWhile(stmt: WhileStmt) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling while statements is not yet implemented", location: stmt.location)
    }
}
