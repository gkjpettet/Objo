//
//  Compiler.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

import Foundation

public class Compiler: ExprVisitor, StmtVisitor {
        
    // MARK: - Class constants
    
    /// Maps the number of bytes used for operands for a particular opcode. Key = Opcode, value = number of bytes used.
    public static let opcodeOperandByteCount: [Opcode : Int] = [
        .add                : 0,
        .add1               : 0,
        .assert             : 0,
        .breakpoint         : 0,
        .bitwiseOr          : 0,
        .bitwiseAnd         : 0,
        .bitwiseNot         : 0,
        .bitwiseXor         : 0,
        .call               : 1, // arg count (ui8)
        .constant           : 1, // constant pool index (ui8)
        .constantLong       : 2, // constant pool index (ui16)
        .constructor        : 1, // parameter count (ui8)
        .class_             : 5, // class name, constant index (ui16), isForeign (0 false, 1 true), hierarchy field count, fieldStartIndex
        .divide             : 0,
        .defineGlobal       : 1, // constant pool index of the constant's name (ui8)
        .defineNothing      : 0,
        .debugFieldName     : 3, // field name index in constant pool (ui16), index of the field in `Klass.fields` (ui8)
        .defineGlobalLong   : 2, // constant pool index of the constant's name (ui16)
        .exit               : 0,
        .equal              : 0,
        .false_             : 0,
        .foreignMethod      : 4, // constant pool index of the signature (ui16), arity (ui8), isStatic (0 false, 1 true)
        .greater            : 0,
        .getField           : 1, // index in the current class's `fields` array to access (ui8)
        .getLocal           : 1, // stack slot where the local variable is (ui8)
        .getGlobal          : 1, // constant pool index of the name of the class (ui8)
        .greaterEqual       : 0,
        .getGlobalLong      : 2, // constant pool index of the name of the class (ui16)
        .getLocalClass      : 1, // stack slot (ui8) where the local variable is. The VM will push it's class on to the stack.
        .getStaticField     : 1, // constant pool index (ui8) of the name of the static field
        .getStaticFieldLong : 2, // constant pool index (ui16) of the name of the static field
        .invoke             : 2, // constant pool index (ui8) of the method to invoke's signature, arg count (ui8)
        .inherit            : 0,
        .is_                : 0,
        .invokeLong         : 3, // constant pool index (ui16) of the method to invoke's signature, arg count (ui8)
        .jump               : 2, // the number of bytes to jump (ui16)
        .jumpIfTrue         : 2, // the number of bytes to jump (ui16)
        .jumpIfFalse        : 2, // the number of bytes to jump (ui16)
        .keyValue           : 0,
        .less               : 0,
        .list               : 1, // the number of initial elements (ui8)
        .loop               : 2, // the number of bytes to jump (ui16)
        .load0              : 0,
        .load1              : 0,
        .load2              : 0,
        .lessEqual          : 0,
        .loadMinus1         : 0,
        .loadMinus2         : 0,
        .logicalXor         : 0,
        .localVarDeclaration: 3, // constant pool index (ui16) of the variable name, stack slot where the variable is (ui8)
        .map                : 1, // the number of initial key-value pairs (ui8)
        .method             : 3, // constant pool index (ui16) of the method signature, isStatic (0 = false, 1 = true)
        .modulo             : 0,
        .multiply           : 0,
        .not                : 0,
        .negate             : 0,
        .nothing            : 0,
        .notEqual           : 0,
        .pop                : 0,
        .popN               : 1, // the number of values to pop off the stack (ui8)
        .return_            : 0,
        .rangeExclusive     : 0,
        .rangeInclusive     : 0,
        .swap               : 0,
        .subtract           : 0,
        .subtract1          : 0,
        .setField           : 1, // the index of the field (ui8)
        .setLocal           : 1, // the stack slot where the local variable is (ui8)
        .setGlobal          : 1, // constant pool index (ui8) of the name of the variable to get
        .shiftLeft          : 0,
        .shiftRight         : 0,
        .superInvoke        : 5, // constant pool index of the name of the superclass (ui16), constant pool index of the method name (ui16), arg count (ui8)
        .superSetter        : 4, // constant pool index of the name of the superclass (ui16), constant pool index of the setter signature (ui16)
        .superConstructor   : 3, // constant pool index of the name of the superclass (ui16), argt count (ui8)
        .setGlobalLong      : 2, // constant pool index (ui16) of the name of the variable to get
        .setStaticField     : 1, // constant pool index (ui16) of the field name to assign the value on the top of the stack to
        .setStaticFieldLong : 2, // constant pool index (ui16) of the field name to assign the value on the top of the stack to
        .true_              : 0
    ]
    
    /// The script ID value the compiler uses for the core library.
    public static let CORE_LIBRARY_SCRIPT_ID: Int = -1
    
    /// The script ID used by the compiler for the synthetic opening and closing braces around the `*main*` function.
    public static let MAIN_SCRIPT_ID = -2
    
    /// The maximum number of local variables that can be in scope at one time.
    /// Limited to one byte due to the instruction's operand size.
    private let MAX_LOCALS = 256
    
    /// The maximum jump distance in bytes (UInt16 max).
    private let MAX_JUMP = 65535
    
    // MARK: - Private properties
    
    /// The abstract syntax tree this compiler is compiling.
    private var ast: [Stmt] = []
    
    /// The time take for the last compilation took.
    private var compileTime: TimeInterval?
    
    /// `true` if the currently compiler is compiling a method or constructor.
    private var isCompilingMethodOrConstructor: Bool {
        return self.type == .method || self.type == .constructor
    }
    
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
    
    /// Adds the `value` to the current function's constant pool and returns its index in the pool.
    ///
    /// - Throws `CompilerError` if the maximum number of constants has been reached.
    private func addConstant(value: Value) throws -> Int {
        let index = currentChunk.addConstant(value)
        
        if index > Chunk.MAX_CONSTANTS {
            try error(message: "Too many constants in the chunk.")
        }
        
        return index
    }
    
    /// Tracks the existence of a global variable named `name`.
    private func addGlobal(name: String) {
        // Only the outermost compiler stores the names of defined globals.
        outermostCompiler.knownGlobals[name] = false
    }
    
    /// Tracks a local variable in the current scope.
    private func addLocal(identifier: Token, initialised: Bool = false) throws {
        if locals.count >= MAX_LOCALS {
            try error(message: "Too many local variables in scope.")
        }
        
        // Set the local's depth to `-1` if not yet initialised.
        locals.append(LocalVariable(identifier: identifier, depth: initialised ? scopeDepth : -1))
    }
    
    /// Compiles an assignment to a variable or setter named `name`.
    ///
    /// The value to assign is assumed to already be on the top of the stack.
    ///
    /// - Throws CompilerError if:
    ///     - This is a local variable and there are > 255 local variables in scope.
    ///     -
    private func assignment(name: String) throws {
        // Check for the simplest case (an assignment to a local variable).
        let stackIndex = try resolveLocal(name: name)
        if stackIndex != -1 {
            if stackIndex > 255 {
                try error(message: "Too many local variables in scope (the maximum is 255).")
            }
            emitOpcode8(opcode: .setLocal, operand: UInt8(stackIndex))
            return
        }
        
        var isSetter = false
        var assumeGlobal = false
        
        // Compute the signature, assuming it's a setter method.
        // This will be ignored if it transpires this is not a setter method call.
        let signature = try Objo.computeSignature(name: name, arity: 1, isSetter: true)
        
        // Is this actually a call to a setter method?
        if isCompilingMethodOrConstructor {
            
            if hierarchyContains(subclass: currentClass, signature: signature, isStatic: false) {
                // Instance setter method.
                isSetter = true
                if self.isStaticMethod {
                    try error(message: "Cannot call an instance setter method from within a static method.")
                } else {
                    // Slot 0 of the call frame will be the instance. Push it onto the stack.
                    emitOpcode8(opcode: .getLocal, operand: 0)
                }
                
            } else if hierarchyContains(subclass: currentClass, signature: signature, isStatic: true) {
                // Static setter method.
                isSetter = true
                if self.isStaticMethod {
                    // We're calling a static method from within a static method. Therefore, slot 0 of the call frame
                    // will be the **class**. Push it onto the stack.
                    emitOpcode8(opcode: .getLocal, operand: 0)
                } else {
                    // We're calling a static method from within an instance method. Therefore, slot 0 of the
                    // call frame will be the *instance*. Push its class onto the stack.
                    emitOpcode8(opcode: .getLocalClass, operand: 0)
                }
            } else {
                // Can't find a local variable or setter with this name. Assume it's a global variable.
                assumeGlobal = true
            }
            
        } else {
            
            // Since we're not within a method or a constructor we'll assume this is an assignment to
            // a global variable.
            assumeGlobal = true
        }
        
        if assumeGlobal {
            
            if globalExists(name: name) {
                // Add the name of the variable to the chunk's constant table and get its index.
                let constantIndex = try addConstant(value: .string(name))
                try emitVariableOpcode(shortOpcode: .setGlobal, longOpcode: .setGlobalLong, operand: constantIndex)
            } else {
                try error(message: "Undefined global variable `\(name)`.")
            }
            
        } else if isSetter {
            // Currently, the top of the stack is the class (if this is a static method) or the instance
            // (if an instance method) containing the setter and underneath it is the setter's argument.
            // We need to swap this.
            emitOpcode(.swap)
            
            // Load the method's signature into the chunk's constant table.
            let signatureIndex = try addConstant(value: .string(signature))
            
            // Emit the `invoke` instruction and the index of the setter's signature in the constant table.
            try emitVariableOpcode(shortOpcode: .invoke, longOpcode: .invokeLong, operand: signatureIndex)
            
            // Emit the argument count (always 1 for setters).
            emitByte(byte: 1)
        }
    }
    
    /// Begins a new scope.
    private func beginScope() {
        scopeDepth += 1
    }
    
    /// Compiles a call to a global function.
    /// There is no guarantee that a function exists globally with this name.
    /// That is determined at runtime.
    private func callGlobalFunction(name: String, arguments: [Expr], location: Token) throws {
        currentLocation = location
        
        if arguments.count > 255 {
            try error(message: "A call cannot have more than 255 arguments.")
        }
        
        // Add the name of the method to the constant pool and get its index.
        let functionNameIndex = try addConstant(value: .string(name))
        
        // Retrieve the global function now stored in the constant pool and put it on the stack.
        try emitVariableOpcode(shortOpcode: .getGlobal, longOpcode: .getGlobalLong, operand: functionNameIndex, location: location)
        
        // Compile the arguments.
        for arg in arguments {
            try arg.accept(self)
        }
        
        // Emit the `call` instruction with the number of arguments as its operand.
        emitOpcode8(opcode: .call, operand: UInt8(arguments.count))
    }
    
    /// Compiles a call to a local variable.
    ///
    /// E.g:
    ///
    /// ```objo
    /// localVariable() # <-- where this is known to be a local variable.
    /// ```
    private func callLocalVariable(stackSlot: Int, arguments: [Expr], location: Token) throws {
        currentLocation = location
        
        if stackSlot > 255 {
            try error(message: "The local variable slot must be <= 255.")
        }
        
        if arguments.count > 255 {
            try error(message: "A call cannot have more than 255 arguments.")
        }
        
        // Tell the VM to push the local variable at `stackSlot` to the top of the stack.
        emitOpcode8(opcode: .getLocal, operand: UInt8(stackSlot))
        
        // Compile the arguments.
        for arg in arguments {
            try arg.accept(self)
        }
        
        // Emit the `call` instruction with the number of arguments as its operand.
        emitOpcode8(opcode: .call, operand: UInt8(arguments.count))
    }
    
    /// Compiles a `++` or `--` postfix expression.
    /// Assumes `expr` is a `++` or `--` expression.
    private func compilePostfix(expr: PostfixExpr) throws {
        // The `++` and `--` operators require a variable or field as their left hand operand.
        switch expr.operand {
        case is VariableExpr, is FieldExpr, is StaticFieldExpr:
            // Allowed.
            break
        default:
            try error(message: "The posfix `\(expr.operator_)` operator expects a variable or field as its operand.")
        }
        
        // Compile the operand.
        try expr.operand.accept(self)
        
        // Manipulate the operand.
        switch expr.operator_ {
        case .plusPlus:
            // Increment the value on the top of the stack by 1.
            emitOpcode(.add1)
            
        case .minusMinus:
            // Decrement the value on the top of the stack by 1.
            emitOpcode(.subtract1)
            
        default:
            break
        }
        
        // Do the assignment.
        switch expr.operand {
        case let ve as VariableExpr:
            try assignment(name: ve.name)
            
        case let fe as FieldExpr:
            try fieldAssignment(fieldName: fe.name)
            
        case let sfe as StaticFieldExpr:
            try staticFieldAssignment(fieldName: sfe.name)
            
        default:
            // This should never be reached because of the checks above...
            break
        }
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
    
    /// Generates code for the VM to discard local variables at `depth` or greater. Does *not*
    /// actually undeclare variables or pop any scopes. Returns the number of local variables that were eliminated.
    ///
    /// This is called directly when compiling `continue` and `exit` statements to ditch the local variables
    /// before jumping out of the loop even though they are still in scope *past* the exit instruction.
    @discardableResult private func discardLocals(depth: Int) throws -> Int {
        if scopeDepth < 0 {
            try error(message: "Cannot exit top-level scope.")
        }
        
        // How many locals do we need to pop?
        var local = locals.count - 1
        var discardCount = 0
        while local >= 0 && locals[local].depth >= depth {
            discardCount += 1
            local -= 1
        }
        
        emitOpcode8(opcode: .popN, operand: UInt8(discardCount))
        
        return discardCount
    }
    
    /// Appends a single byte to the current chunk at the current location.
    /// An optional `location` can be provided.
    private func emitByte(byte: UInt8, location: Token? = nil) {
        currentChunk.writeByte(byte, token: location ?? currentLocation!)
    }
    
    /// Adds the `value` to the current chunk's constant pool at the current location and pushes it to the stack.
    ///
    /// Returns the index in the constant table or `-1` if the value has a dedicated opcode accessor.
    @discardableResult private func emitConstant(value: Value, location: Token? = nil) throws -> Int {
        let loc = location ?? currentLocation
        
        // The VM has dedicated instructions for producing certain numeric constants that are commonly used.
        switch value {
        case .number(let d):
            switch d {
            case 0.0:
                emitOpcode(.load0, location: loc)
                return -1
                
            case 1.0:
                emitOpcode(.load1, location: loc)
                return -1
                
            case 2.0:
                emitOpcode(.load2, location: loc)
                return -1
                
            default:
                break
            }
        default:
            break
        }
        
        // Add this constant to the chunk's constant table.
        let index = try addConstant(value: value)
        
        // Tell the VM to produce the constant.
        try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
        
        // Return the index in the chunk's constant table.
        return index
    }
    
    /// Emits the jump `instruction` occuring at source `location` (or the current location if `nil`)
    /// and writes a placeholder (&hFFFF) for the jump offset.
    /// Returns the offset of the jump instruction.
    ///
    /// We can jump a maximum of &hFFFF (65535) bytes.
    private func emitJump(instruction: Opcode, location: Token? = nil) -> Int {
        let loc = location ?? currentLocation!
        
        emitOpcode(instruction, location: loc)
        
        emitByte(byte: 0xFF, location: loc)
        emitByte(byte: 0xFF, location: loc)
        
        return currentChunk.length - 2
    }
    
    /// Emits a new loop instruction which unconditionally jumps backwards to `loopStart`.
    /// If `location` is `nil` we use the current location.
    private func emitLoop(loopStart: Int, location: Token? = nil) throws {
        emitOpcode(.loop)
        
        // Compute the offset to subtract from the VM's instruction pointer.
        // +2 accounts for the `loop` instruction's own operands which we also need to jump over.
        let offset = currentChunk.length - loopStart + 2
        
        if offset > MAX_JUMP {
            try error(message: "Maximal loop body size exceeded.")
        }
        
        // Emit the 16-bit offset.
        emitUInt16(value: UInt16(offset), location: location ?? currentLocation!)
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
    
    /// Emits an opcode followed by `operand`.
    ///
    /// The operand may be one or two bytes in length. If `operand` is one byte then `shortOpcode` is emitted before the operand, otherwise `longOpcode` is emitted.
    ///
    /// If `index <= 255` then `shortOpcode` is emitted followed by the single byte `index`.
    ///
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
    
    /// Ends the current innermost loop. Patches up all jumps and exits now that
    /// we know where the end of the loop is.
    private func endLoop() throws {
        guard let loop = currentLoop else {
            try error(message: "Not currently compiling a loop.")
            return
        }
        
        // Jump back to the start of the current loop if the condition evaluates to truthy.
        try emitLoop(loopStart: loop.start, location: loop.startToken)
        
        // Back-patch the jump.
        try patchJump(offset: loop.exitJump)
        
        // The condition must have been falsey - pop the condition off the stack.
        emitOpcode(.pop)
        
        // Find any `exit` placeholder instructions (which will be `.exit` in the
        // bytecode) and replace them with real jumps.
        var i = loop.bodyOffset
        while i < currentChunk.length {
            if currentChunk.code[i] == Opcode.exit.rawValue {
                currentChunk.code[i] = Opcode.jump.rawValue
                try patchJump(offset: i + 1)
                i += 3
            } else {
                // Skip this instruction and its operands.
                
                // Firsyt get the opcode at this offset.
                guard let opcode = Opcode(rawValue: currentChunk.code[i]) else {
                    try error(message: "The value at offset \(i) is not a valid opcode.")
                    return
                }
                
                // Determine how many bytes are used for this opcode's operands (if any)
                guard let bytesToSkip = Compiler.opcodeOperandByteCount[opcode] else {
                    try error(message: "Unable to determine the number of bytes used for the operand(s) for opcode `\(opcode)`.")
                    return
                }
                
                i += bytesToSkip + 1
            }
        }
        
        // Mark that we're exiting this loop.
        currentLoop = loop.enclosing
    }
    
    /// Ends the current scope.
    private func endScope() {
        scopeDepth -= 1
        
        // Remove any locals declared in this scope by popping them off the top of the stack.
        var popCount = 0
        while locals.count > 0 && locals.last!.depth > scopeDepth {
            popCount += 1
            locals.removeLast()
        }
        
        // It's more efficient to pop multiple values off the stack at once, therefore we use `popN`.
        if popCount > 0 {
            emitOpcode8(opcode: .popN, operand: UInt8(popCount))
        }
    }
    
    /// Throws a `CompilerError` at the current location.
    /// If the error is not at the current location, `location` may be passed instead.
    private func error(message: String, location: Token? = nil) throws {
        throw CompilerError(message: message, location: location ?? currentLocation)
    }
    
    /// Emits the `jumpIfTrue` instruction and a `pop` instruction to test the loop condition and
    /// potentially exit the loop. Keeps track of the instruction so we can patch it
    /// later once we know where the end of the body is.
    ///
    /// Will throw if there is no loop currently being compiled.
    private func exitLoopIfTrue() throws {
        guard let loop = currentLoop else {
            try error(message: "Not currently compiling a loop.")
            return
        }
        
        loop.exitJump = emitJump(instruction: .jumpIfTrue)
        
        // Pop the condition before executing the body.
        emitOpcode(.pop)
    }
    
    /// Assigns the value on the top of the stack to the specified field.
    private func fieldAssignment(fieldName: String) throws {
        if !isCompilingMethodOrConstructor {
            try error(message: "Fields can only be accessed from within a method or constructor.")
        }
        
        if self.isStaticMethod {
            try error(message: "Instance fields can only be accessed from within an instance method, not a static method.")
        }
        
        // Get the index of the field to access at runtime.
        let fieldIndex = try fieldIndex(fieldName: fieldName)
        
        if fieldIndex > 255 {
            try error(message: "Classes cannot have more than 255 fields, including inherited ones.")
        }
        
        emitOpcode8(opcode: .setField, operand: UInt8(fieldIndex))
    }
    
    /// Returns the field index of `fieldName` for *this* class (not any superclasses).
    /// This is the index the runtime will access.
    /// If there is no field with this name then a new one is created.
    private func fieldIndex(fieldName: String) throws -> Int {
        if currentClass == nil {
            try error(message: "Instance fields can only be accessed from within an instance method or constructor.")
        }
        
        for (i, field) in currentClass!.fields.enumerated() {
            if field == fieldName {
                return currentClass!.fieldStartIndex + i
            }
        }
        
        // Doesn't exist yet. Add it.
        currentClass!.fields.append(fieldName)
        
        return currentClass!.fieldStartIndex + currentClass!.fields.count - 1
    }
    
    /// Checks this compiler's known classes and all of its enclosing compilers for the named class.
    private func findClass(name: String) -> ClassData? {
        // Known to this compiler?
        if knownClasses[name] != nil {
            return knownClasses[name]
        }
        
        // Walk the compiler hierarchy.
        var parent: Compiler? = enclosing
        while parent != nil {
            if parent!.knownClasses[name] != nil {
                return parent!.knownClasses[name]
            } else {
                parent = parent!.enclosing
            }
        }
        
        return nil
    }
    
    /// Tells the VM to retrieve a global variable named `name` and push it on to the stack.
    private func getGlobalVariable(name: String) throws {
        // Get the index of the variable in the constants table (or add it and
        // then get its index if not already present).
        let index = try addConstant(value: .string(name))
        
        // Push the variable on to the stack.
        try emitVariableOpcode(shortOpcode: .getGlobal, longOpcode: .getGlobalLong, operand: index, location: currentLocation)
    }
    
    /// Returns `true` if a global variable named `name` has already been defined by this compiler chain.
    private func globalExists(name: String) -> Bool {
        return outermostCompiler.knownGlobals[name] != nil
    }
    
    /// Returns `true` if `subclass` has (or has inherited) a method with `signature`.
    ///
    /// - Parameter isStatic: Determines whether or not we search static or instance methods.
    ///
    /// Only searches static **or** instance methods. Not both.
    private func hierarchyContains(subclass: ClassData? , signature: String, isStatic: Bool) -> Bool {
        guard let subclass = subclass else {
            return false
        }
        
        if subclass.declaration.hasMethod(signature: signature, isStatic: isStatic) {
            return true
        } else {
            if subclass.superclass != nil {
                return hierarchyContains(subclass: findClass(name: subclass.superclass!.name), signature: signature, isStatic: isStatic)
            } else {
                return false
            }
        }
    }
    
    /// Compiles a logical `and` expression.
    private func logicalAnd(expr: LogicalExpr) throws {
        currentLocation = expr.location
        
        // Compile the left hand operand to leave it on the VM's stack.
        try expr.left.accept(self)
        
        // Since `and` short circuits, if the left hand operand is `false` then the
        // whole expression is `false` so we jump over the right operand and leave the left
        // operand on the top of the stack.
        let endJump = emitJump(instruction: .jumpIfFalse, location: expr.location)
        
        // If the left hand operand was false then we need to pop it off the stack.
        emitOpcode(.pop)
        
        // Compile the right hand operand.
        try expr.right.accept(self)
        
        // Back-patch the jump instruction.
        try patchJump(offset: endJump)
    }
    
    /// Compiles a logical `or` expression.
    private func logicalOr(expr: LogicalExpr) throws {
        currentLocation = expr.location
        
        // Compile the left hand operand to leave it on the VM's stack.
        try expr.left.accept(self)
        
        // Since the logical operators short circuit, if the left hand operand is true then
        // we jump over the right hand operand.
        let endJump = emitJump(instruction: .jumpIfTrue, location: expr.location)
        
        // If the left operand was false we need to pop it off the stack.
        emitOpcode(.pop)
        
        // The right hand operand only gets evaluated if the left operand was false.
        try expr.right.accept(self)
        
        // Back-patch the jump instruction.
        try patchJump(offset: endJump)
    }
    
    /// Compiles the body of a loop and tracks its extent so that contained `break`
    /// statements can be handled correctly.
    private func loopBody(_ body: BlockStmt?) throws {
        if currentLoop == nil {
            try error(message: "Not currently compiling a loop.")
        }
        
        currentLoop!.bodyOffset = currentChunk.length
        
        // Compile the optional loop body.
        if body != nil {
            try body?.accept(self)
        }
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
    
    /// Takes the offset in the current chunk of the start of a jump placeholder and
    /// replaces that placeholder with the the amount needed to added to the VM's instruction pointer to
    /// cause it to jump to the current position in the chunk.
    private func patchJump(offset: Int) throws {
        // Compute the distance to jump to get from the end of the placeholder operand to
        // the current offset in the chunk.
        // -2 to adjust for the bytecode for the jump offset itself.
        let jumpDistance = currentChunk.length - offset - 2
        
        if jumpDistance > MAX_JUMP {
            try error(message: "Maximum jump distance exceeded.")
        }
        
        // Replace the 16-bit placeholder with the jump distance.
        let msb = UInt8((jumpDistance >> 8) & 0xFF)
        let lsb = UInt8(jumpDistance & 0xFF)
        currentChunk.code[offset] = msb
        currentChunk.code[offset + 1] = lsb
    }
    
    /// Returns the stack index of the local variable named `name` or `-1` if there is
    /// no matching local variable with that name.
    ///
    /// If `-1` is returned we assume (maybe falsely) that the variable is global.
    ///
    /// This works because when we declare a local variable we append it to `locals`.
    /// This means that the first declared variable is at index 0, the next one at index 1 and so on.
    /// Therefore the `locals` array in the compiler has the _exact_ same layout as the VM's stack
    /// will have at runtime. Therefore the variable's index in `locals` is the same as its
    /// stack slot, relative to its call frame.
    private func resolveLocal(name: String) throws -> Int {
        // Walk the list of local variables that are currently in scope.
        // If one is named `name` then we've found it.
        // We walk backwards so we find the _last_ declared variable named `name`
        // which ensures that inner local variables correctly shadow locals with the
        // same name in surrounding scopes.
        for (i, local) in locals.reversed().enumerated() {
            if name == local.name {
                // Ensure that this local variable has been initialised.
                if local.depth == -1 {
                    try error(message: "You can't read a local variable in its own initialiser.")
                }
                return i
            }
        }
        
        // There is no local variable with this name. It should therefore be assumed to be global.
        return -1
    }
    
    /// Marks the beginning of a loop. Keeps track of the current instruction so we
    /// know what to loop back to at the end of the body.
    private func startLoop(location: Token? = nil) {
        let newLoop = LoopData(bodyOffset: 0, enclosing: currentLoop, exitJump: 0, scopeDepth: scopeDepth, start: currentChunk.length, startToken: location ?? currentLocation!)
        
        currentLoop = newLoop
    }
    
    /// Assigns the value on the top of the stack to the static field named `fieldName`.
    private func staticFieldAssignment(fieldName: String) throws {
        if !isCompilingMethodOrConstructor {
            try error(message: "Static fields can only be accessed from within a method or constructor.")
        }
        
        // Add the name of the field to the constants table and get its index.
        let index = try addConstant(value: .string(fieldName))
        
        // Tell the VM to assign the value on the top of the stack to this field.
        try emitVariableOpcode(shortOpcode: .setStaticField, longOpcode: .setStaticFieldLong, operand: index)
    }
    
    /// Compiles a call to a superclass constructor.
    ///
    /// E.g: `super` or `super(argN)`.
    /// Assumes the compiler is currently compiling a constructor and that the
    /// current class being compiled has a superclass.
    private func superConstructorInvocation(arguments: [Expr], location: Token) throws {
        currentLocation = location
        
        // Check the superclass has a constructor with this many arguments.
        if arguments.count > 0 {
            var superHasMatchingConstructor = false
            for constructor in currentClass!.superclass!.declaration.constructors {
                if constructor.arity == arguments.count {
                    superHasMatchingConstructor = true
                    break
                }
            }
            if !superHasMatchingConstructor {
                try error(message: "The superclass (`\(currentClass!.superclass!.name)`) of `\(currentClass!.name)` does not define a constructor with \(arguments.count) arguments.")
            }
        }
        
        // Load the superclass' name into the constant pool.
        let superNameIndex = try addConstant(value: .string(currentClass!.superclass!.name))
        
        // Push `this` onto the stack. It's always at slot 0 of the call frame.
        emitOpcode8(opcode: .getLocal, operand: 0)
        
        // Compile the arguments.
        for arg in arguments {
            try arg.accept(self)
        }
        
        // Emit the `superConstructor` instruction, the index of the superclass' name
        // and the argument count.
        emitOpcode(.superConstructor, location: location)
        emitUInt16(value: UInt16(superNameIndex), location: location)
        emitByte(byte: UInt8(arguments.count), location: location)
    }
    
    /// Compiles a method invocation on `super`. E.g: super.method(arg1, arg2).
    ///
    /// Assumes the compiling is currently compiling a method within a class
    /// and that the current class has a superclass.
    private func superMethodInvocation(signature: String, arguments: [Expr], location: Token) throws {
        currentLocation = location
        
        if currentClass == nil {
            try error(message: "`super` can only be used within a method or constructor.")
        }
        
        // Check the superclass has a matching method.
        if !hierarchyContains(subclass: currentClass!.superclass, signature: signature, isStatic: false) {
            try error(message: "The superclass (`\(currentClass!.superclass!.name)`) of `\(currentClass!.name)` does not define `\(signature)`.")
        }
        
        // Load the superclass' name into the constant pool.
        let superNameIndex = try addConstant(value: .string(currentClass!.superclass!.name))
        
        // Push `this` onto the stack. It's always at slot 0 of the call frame.
        emitOpcode8(opcode: .getLocal, operand: 0)
        
        // Load the method's signature into the constant pool.
        let signatureIndex = try addConstant(value: .string(signature))
        
        // Compile the arguments.
        for arg in arguments {
            try arg.accept(self)
        }
        
        // Emit the `superInvoke` instruction, the superclass name, the index of the
        // method's signature in the constant pool and the argument count.
        emitOpcode(.superInvoke, location: location)
        emitUInt16(value: UInt16(superNameIndex), location: location)
        emitUInt16(value: UInt16(signatureIndex), location: location)
        emitByte(byte: UInt8(arguments.count), location: location)
    }
    
    // MARK: - `ExprVisitor` protocol methods
    
    /// Compiles the assignment of a value to a variable.
    public func visitAssignment(expr: AssignmentExpr) throws {
        currentLocation = expr.location
        
        // Compile the value to be assigned.
        try expr.value.accept(self)
        
        try assignment(name: expr.name)
    }
    
    /// Compiles a bare method invocation.
    /// Must be either a global function call or a local method invocation on `this`
    ///
    /// E.g:
    ///
    /// ```objo
    /// someIdentifier()
    /// ```
    public func visitBareInvocation(expr: BareInvocationExpr) throws {
        currentLocation = expr.location
        
        if expr.arguments.count > 255 {
            try error(message: "An invocation cannot have more than 255 arguments.")
        }
        
        // Simplest case - are we invoking a local variable?
        let stackSlot = try resolveLocal(name: expr.methodName)
        if stackSlot != -1 {
            try callLocalVariable(stackSlot: stackSlot, arguments: expr.arguments, location: expr.location)
            return
        }
        
        // Is this an instance or static method invocation called from within a class?
        var isMethod = false
        var isStatic = false
        if hierarchyContains(subclass: currentClass, signature: expr.signature, isStatic: false) {
            isMethod = true
        } else if hierarchyContains(subclass: currentClass, signature: expr.signature, isStatic: true) {
            isMethod = true
            isStatic = true
        }
        
        // Shall we assume this is this a call to a global function?
        if !isMethod {
            try callGlobalFunction(name: expr.methodName, arguments: expr.arguments, location: expr.location)
            return
        }
        
        if isStatic {
            if self.isStaticMethod {
                // Calling a static method from within a static method.
                // Slot 0 of the call frame will be the **class**.
                emitOpcode8(opcode: .getLocal, operand: 0)
            } else {
                // Calling a static method from within an instance method.
                // Slot 0 of the call frame will be the *instance*. Push *its* class onto the stack.
                emitOpcode8(opcode: .getLocalClass, operand: 0)
            }
        } else {
            if self.isStaticMethod {
                try error(message: "Cannot call an instance method from within a static method.")
            } else {
                // We're calling an instance method.
                // Slot 0 of the call frame will be the *instance*. Push it onto the stack.
                emitOpcode8(opcode: .getLocal, operand: 0)
            }
        }
        
        // The class (if this is a static method) or the instance will be on the top of the stack.
        // Load the method's signature into the constant pool.
        let signatureIndex = try addConstant(value: .string(expr.signature))
        
        // Compile the arguments.
        for arg in expr.arguments {
            try arg.accept(self)
        }
        
        // Emit the `invoke` instruction and the index of the method's signature in the constant pool.
        try emitVariableOpcode(shortOpcode: .invoke, longOpcode: .invokeLong, operand: signatureIndex, location: expr.location)
        
        // Emit the argument count.
        emitByte(byte: UInt8(expr.arguments.count), location: expr.location)
    }
    
    /// Compiles a bare super invocation. E.g: `super` or `super(argN)`
    public func visitBareSuperInvocation(expr: BareSuperInvocationExpr) throws {
        currentLocation = expr.location
        
        if !isCompilingMethodOrConstructor {
            try error(message: "`super` can only be used within a method or constructor.")
        }
        
        if currentClass == nil {
            try error(message: "`super` can only be used within a class.")
        }
        
        if currentClass!.superclass == nil {
            try error(message: "Class `\(currentClass!.name)` does not have a superclass.")
        }
        
        // Are we calling the superclass's constructor?
        if self.type == .constructor {
            // Assert that calls to constructors have parentheses (even when there are no arguments).
            // This is an Objo language requirement.
            if !expr.hasParentheses {
                try error(message: "A superclass constructor must have an argument list, even if empty.")
            }
            try superConstructorInvocation(arguments: expr.arguments, location: expr.location)
            return
        }
        
        if self.type == .method {
            // This is a call to a method on the superclass with the same name as
            // the method that we're currently compiling.
            try superMethodInvocation(signature: function!.signature, arguments: expr.arguments, location: expr.location)
            return
        }
        
        try error(message: "`super` can only be used within a method or constructor.")
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
    	
    /// Compiles a call expression. E.g: `identifier()`.
    public func visitCall(expr: CallExpr) throws {
        currentLocation = expr.location
        
        if expr.arguments.count > 255 {
            try error(message: "A call cannot have more than 255 arguments.")
        }
        
        // Compile the callee.
        try expr.callee.accept(self)
        
        // Compile the arguments.
        for arg in expr.arguments {
            try arg.accept(self)
        }
        
        // Emit the `call` instruction with the number of arguments as its operand.
        emitOpcode8(opcode: .call, operand: UInt8(expr.arguments.count))
    }
    
    /// Compiles retrieving a global class.
    ///
    /// In Objo, classes are always defined globally.
    public func visitClass(expr: ClassExpr) throws {
        // Add the name of the class to the constant pool and get its index.
        let nameIndex = try addConstant(value: .string(expr.name))
        
        // Tell the VM to retrieve the requested global variable (which we're assuming is a class)
        // and push it on to the stack.
        try emitVariableOpcode(shortOpcode: .getGlobal, longOpcode: .getGlobalLong, operand: nameIndex)
    }
    
    /// Compiles retrieving an instance field.
    public func visitField(expr: FieldExpr) throws {
        if !isCompilingMethodOrConstructor {
            try error(message: "Instance fields can only be accessed from within an instance method or constructor.")
        }
        
        if self.isStaticMethod {
            try error(message: "Instance fields can only be accessed from within an instance method, not a static method.")
        }
        
        // Get the index in this class' `fields` array to access at runtime.
        let index = try fieldIndex(fieldName: expr.name)
        
        if index > 255 {
            try error(message: "Classes cannot have more than 255 fields, including inherited ones.")
        }
        
        // Tell the VM to produce the field's value.
        emitOpcode8(opcode: .getField, operand: UInt8(index))
    }
    
    /// Compiles a field assignment.
    public func visitFieldAssignment(expr: FieldAssignmentExpr) throws {
        // Compile the value to assign, leaving it on the top of the stack.
        try expr.value.accept(self)
        
        // Assign the value on the top of the stack to this field.
        try fieldAssignment(fieldName: expr.name)
    }
    
    /// Compiles a key-value literal.
    public func visitKeyValue(expr: KeyValueExpr) throws {
        currentLocation = expr.location
        
        // Retrieve the `KeyValue` class. It should have been defined globally in the standard library.
        try getGlobalVariable(name: "KeyValue")
        
        // Compile the value.
        try expr.value.accept(self)
        
        // Compile the key.
        try expr.key.accept(self)
        
        // Tell the VM to create a new `KeyValue` instance.
        emitOpcode(.keyValue, location: expr.location)
    }
    
    /// Compiles a list literal.
    public func visitListLiteral(expr: ListLiteral) throws {
        currentLocation = expr.location
        
        // Retrieve the List class. It should have been defined globally in the standard library.
        try getGlobalVariable(name: "List")
        
        // Make sure no more than 255 initial elements are defined.
        if expr.elements.count > 255 {
            try error(message: "The maximum number of initial elements for a list is 255.")
        }
        
        // Any initial elements need compiling to leave them on the top of the stack.
        for element in expr.elements {
            try element.accept(self)
        }
        
        // Tell the VM to create a `List` instance with the optional initial elements.
        emitOpcode8(opcode: .list, operand: UInt8(expr.elements.count), location: expr.location)
    }
    
    /// The compiler is visiting a logical expression (or, and, xor).
    public func visitLogical(expr: LogicalExpr) throws {
        currentLocation = expr.location
        
        switch expr.op {
        case .and:
            try logicalAnd(expr: expr)
            
        case .or:
            try logicalOr(expr: expr)
            
        case .xor:
            try expr.left.accept(self)
            try expr.right.accept(self)
            emitOpcode(.logicalXor)
            
        default:
            try error(message: "Unsupported logical operator: \(expr.op).")
        }
    }
    
    /// Compiles a method invocation.
    ///
    /// E.g: `operand.method(arg1, arg2)`
    public func visitMethodInvocation(expr: MethodInvocationExpr) throws {
        currentLocation = expr.location
        
        // Compile the operand to put it on the stack.
        try expr.operand.accept(self)
        
        // Load the method's signature into the constant pool.
        let index = try addConstant(value: .string(expr.signature))
        
        if expr.arguments.count > 255 {
            try error(message: "The maximum number of arguments is 255.")
        }
        
        // Compile the arguments.
        for arg in expr.arguments {
            try arg.accept(self)
        }
        
        // Emit the `invoke` instruction and the index of the method's signature in the constant pool.
        try emitVariableOpcode(shortOpcode: .invoke, longOpcode: .invokeLong, operand: index, location: expr.location)
        
        // Emit the argument count.
        emitByte(byte: UInt8(expr.arguments.count), location: expr.location)
    }
    
    /// Compiles an `is` expression.
    public func visitIs(expr: IsExpr) throws {
        currentLocation = expr.location
        
        // Compile the value operand - this will leave it on the stack.
        try expr.value.accept(self)
        
        // Compile the type to put it on the stack.
        try expr.type.accept(self)
        
        // Emit the instruction.
        emitOpcode(.is_, location: expr.location)
    }
    
    /// Compiles a `Map` literal.
    public func visitMapLiteral(expr: MapLiteral) throws {
        currentLocation = expr.location
        
        // Retrieve the `Map` class. It should have been defined globally in the standard library.
        try getGlobalVariable(name: "Map")
        
        if expr.keyValues.count > 255 {
            try error(message: "The maximum number of initial key-value pairs for a map is 255.")
        }
        
        // Compile the key-value pairs.
        // We compile in reverse order compared to how they were parsed which means the first key-value
        // popped off the stack by the VM will be the first one in the literal.
        // E.g: `{a : b, c : d}` compiles to:
        // ```
        // a         <-- stack top
        // b
        // c
        // d
        // Map class
        // ```
        for kv in expr.keyValues.reversed() {
            // Compile the value.
            try kv.value.accept(self)
            
            // Compile the key.
            try kv.key.accept(self)
        }
        
        // Tell the VM to create a `Map` instance with the optional initial key-values.
        emitOpcode8(opcode: .map, operand: UInt8(expr.keyValues.count))
    }
    
    /// Tell the VM to push the singleton `nothing` instance to the stack.
    public func visitNothing(expr: NothingLiteral) throws {
        currentLocation = expr.location
        emitOpcode(.nothing)
    }
    
    /// The VM should produce a numeric constant.
    public func visitNumber(expr: NumberLiteral) throws {
        currentLocation = expr.location
        
        // The VM has dedicated instructions for producing certain integer constants that are commonly used.
        if expr.isInteger {
            switch expr.value {
            case 0.0:
                emitOpcode(.load0)
                
            case 1.0:
                emitOpcode(.load1)
                
            case 2.0:
                emitOpcode(.load2)

            default:
                // Add this number to the chunk's constant table.
                let index = currentChunk.addConstant(.number(expr.value))
                
                // Tell the VM to retrieve this constant.
                try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
            }
        }
    }
    
    /// Compiles a postfix expression.
    public func visitPostfix(expr: PostfixExpr) throws {
        currentLocation = expr.location
        
        switch expr.operator_ {
        case .plusPlus, .minusMinus:
            try compilePostfix(expr: expr)
            
        default:
            try error(message: "Unknown postfix operator `\(expr.operator_)`.")
        }
    }
    
    /// Compiles an inclusive (...) or exclusive (..<) range expression.
    ///
    /// `a RANGE_OP b` becomes:
    /// ```
    ///  RANGE_OP
    ///  b   ← top of the stack
    ///  a
    ///  ```
    public func visitRange(expr: RangeExpr) throws {
        currentLocation = expr.location
        
        // Compile the left and right operands - this will leave them on the stack.
        try expr.lower.accept(self)
        try expr.upper.accept(self)
        
        if expr.isInclusive {
            emitOpcode(.rangeInclusive)
        } else {
            emitOpcode(.rangeExclusive)
        }
    }
    
    /// Compiles retrieving a static field.
    public func visitStaticField(expr: StaticFieldExpr) throws {
        currentLocation = expr.location
        
        if !isCompilingMethodOrConstructor {
            try error(message: "Static fields can only be accessed from within a method or a constructor.")
        }
        
        // Add the name of the field to the constants table and get its index.
        let index = try addConstant(value: .string(expr.name))
        
        // Tell the VM to push the field's value on to the stack.
        try emitVariableOpcode(shortOpcode: .getStaticField, longOpcode: .getStaticFieldLong, operand: index)
    }
    
    /// Compiles a static field assignment.
    public func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr) throws {
        currentLocation = expr.location
        
        // Evaluate the value to assign, leaving it on the top of the stack.
        try expr.value.accept(self)
        
        try staticFieldAssignment(fieldName: expr.name)
    }
    
    /// The VM should produce a string literal.
    public func visitString(expr: StringLiteral) throws {
        currentLocation = expr.location
        
        // Store the string in the chunk's constant table.
        let index = currentChunk.addConstant(.string(expr.value))
        
        // Tell the VM to produce the constant at runtime.
        try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
    }
    
    /// Compiles a subscript method call.
    ///
    /// E.g: `operand[1]`
    public func visitSubscript(expr: SubscriptExpr) throws {
        currentLocation = expr.location
        
        // Compile the operand to put it on the stack.
        try expr.operand.accept(self)
        
        // Load the signature into the constants table.
        let sigIndex = try addConstant(value: .string(expr.signature))
        
        if expr.indexes.count > 255 {
            try error(message: "The maximum number of subscript indexes is 255.")
        }
        
        // Compile the indexes.
        for i in expr.indexes {
            try i.accept(self)
        }
        
        // Emit the `invoke` instruction and the index of the method's signature in the constants table.
        try emitVariableOpcode(shortOpcode: .invoke, longOpcode: .invokeLong, operand: sigIndex, location: expr.location)
        
        // Emit the index count.
        emitByte(byte: UInt8(expr.indexes.count), location: expr.location)
    }
    
    /// Compiles a subscript setter call.
    ///
    /// E.g: `a[1] = value`
    public func visitSubscriptSetter(expr: SubscriptSetterExpr) throws {
        currentLocation = expr.location
        
        // Load the signature into the constants table.
        let sigIndex = try addConstant(value: .string(expr.signature))
        
        // Compile the operand to put it on the stack.
        try expr.operand.accept(self)
        
        // 254 not 255 because the value to assign to a setter has to be accounted for.
        if expr.indexes.count > 254 {
            try error(message: "The maximum number of subscript indexes is 254.")
        }
        
        // Compile the arguments.
        for i in expr.indexes {
            try i.accept(self)
        }
        
        // Compile the value to assign.
        try expr.valueToAssign.accept(self)
        
        // Emit the `invoke` instruction and the index of the signature in the constants table.
        try emitVariableOpcode(shortOpcode: .invoke, longOpcode: .invokeLong, operand: sigIndex, location: expr.location)
        
        // Emit the argument count.
        // +1 because the value to assign is passed as the last argument to the setter method.
        emitByte(byte: UInt8(expr.indexes.count + 1), location: expr.location)
    }
    
    /// Compiles a method invocation on `super`.
    ///
    /// E.g: `super.method(arg1, arg2)`
    public func visitSuperMethodInvocation(expr: SuperMethodInvocationExpr) throws {
        try superMethodInvocation(signature: expr.signature, arguments: expr.arguments, location: expr.location)
    }
    
    /// Compiles a `super` setter expression.
    ///
    /// The runtime needs three things to execute a `super` setter expression.
    ///  1. The superclass name.
    ///  2. The signature of the setter
    ///  3. The value to assign.
    public func visitSuperSetter(expr: SuperSetterExpr) throws {
        currentLocation = expr.location
        
        if !isCompilingMethodOrConstructor {
            try error(message: "`super` can only be used within a method or constructor.")
        }
        
        // Check this class actually has a superclass.
        if currentClass!.superclass == nil {
            try error(message: "Class `\(currentClass!.name)` does not have a superclass.")
        }
        
        // Check the superclass has a matching setter.
        var superHasMatchingSetter = false
        for (_, method) in currentClass!.superclass!.declaration.methods {
            if !method.isSetter {
                continue
            }
            
            if method.signature == expr.signature {
                superHasMatchingSetter = true
                break
            }
        }
        
        if !superHasMatchingSetter {
            try error(message: "The superclass (`\(currentClass!.superclass!.name)`) of `\(currentClass!.name)` does not define a setter `\(expr.signature)`.")
        }
        
        // Load the superclass's name into the constants table.
        let superNameIndex = try addConstant(value: .string(currentClass!.superclass!.name))
        
        // Push `this` onto the stack. It's always at slot 0 of the call frame.
        emitOpcode8(opcode: .getLocal, operand: 0)
        
        // Load the setter's signature into the constants table.
        let sigIndex = try addConstant(value: .string(expr.signature))
        
        // Compile the value to assign.
        try expr.valueToAssign.accept(self)
        
        // Emit the `superSetter` instruction, the superclass name index and the index of the
        // method's signature in the constants table.
        emitOpcode(.superSetter, location: expr.location)
        emitUInt16(value: UInt16(superNameIndex), location: expr.location)
        emitUInt16(value: UInt16(sigIndex), location: expr.location)
    }
    
    /// Compiles a ternary conditional expression.
    public func visitTernary(expr: TernaryExpr) throws {
        currentLocation = expr.location
        
        // Compile the condition - this will leave the result on the top of the stack at runtime.
        try expr.condition.accept(self)
        
        // Emit the "jump if false" instruction. We'll patch this with the proper offset to jump
        // if condition = false after we've compiled the "then branch".
        let thenJump = emitJump(instruction: .jumpIfFalse, location: expr.location)
        
        // Pop the condition if it was true before executing the "then branch".
        emitOpcode(.pop)
        
        // Compile the "then branch" statement(s).
        try expr.thenBranch.accept(self)
        
        // Emit the "unconditional jump" instruction. We'll patch this with the proper offset to jump
        // if condition = true _after_ we've compiled the "else branch".
        let elseJump = emitJump(instruction: .jump, location: expr.location)
        
        try patchJump(offset: thenJump)
        
        // Pop the condition if it was false before executing the "else branch".
        emitOpcode(.pop)
        
        // Compile the "else" branch.
        try expr.elseBranch.accept(self)
        
        try patchJump(offset: elseJump)
    }
    
    /// Compiles a `this` expression.
    public func visitThis(expr: ThisExpr) throws {
        currentLocation = expr.location
        
        if !isCompilingMethodOrConstructor {
            try error(message: "`this` can only be used within a method or constructor.")
        }
        
        // `this` is always at slot 0 of the call frame.
        // `this` can be an instance or a class.
        emitOpcode8(opcode: .getLocal, operand: 0)
    }
    
    /// Compiles a unary expression.
    public func visitUnary(expr: UnaryExpr) throws {
        currentLocation = expr.location
        
        // Emit the correct operator instructor.
        switch expr.operator_ {
        case .minus:
            // We can compile negation of numeric literals more efficiently
            // by letting the compiler negate the value and then emitting it as a constant.
            if expr.operand is NumberLiteral {
                switch (expr.operand as! NumberLiteral).value {
                case 1.0:
                    // -1 has a dedicated opcode.
                    emitOpcode(.loadMinus1, location: expr.operand.location)
                case 2.0:
                    // -2 has a dedicated opcode.
                    emitOpcode(.loadMinus2, location: expr.operand.location)
                default:
                    // Negate the value and emit it as a constant.
                    try emitConstant(value: .number(-(expr.operand as! NumberLiteral).value), location: expr.operand.location)
                }
            } else {
                // Compile the operand.
                try expr.operand.accept(self)
                
                // Emit the negate instruction.
                emitOpcode(.negate)
            }
            
        case .not:
            // Compile the operand.
            try expr.operand.accept(self)
            emitOpcode(.not)
            
        case .tilde:
            // Compile the operand.
            try expr.operand.accept(self)
            emitOpcode(.bitwiseNot)
            
        default:
            try error(message: "Unknown unary operator `\(expr.operator_)`.")
        }
    }
    
    public func visitVariable(expr: VariableExpr) throws {
        // TODO: Implement.
        throw CompilerError(message: "Compiling variable access is not yet implemented", location: expr.location)
    }
    
    // MARK: - `StmtVisitor` protocol methods
    
    /// Compiles an `assert` statement.
    public func visitAssertStmt(stmt: AssertStmt) throws {
        currentLocation = stmt.location
        
        // Compile the condition.
        try stmt.condition.accept(self)
        
        // Compile the message.
        try stmt.message.accept(self)
        
        emitOpcode(.assert, location: stmt.location)
    }
    
    /// Compiles a block of statements.
    public func visitBlock(stmt: BlockStmt) throws {
        beginScope()
        
        for s in stmt.statements {
            try s.accept(self)
        }
        
        endScope()
    }
    
    /// Compiles a break point.
    public func visitBreakpoint(stmt: BreakpointStmt) throws {
        currentLocation = stmt.location
        
        // Break points have no effect in production builds.
        if debugMode { emitOpcode(.breakpoint) }
    }
    
    public func visitCase(stmt: CaseStmt) throws {
        // The compiler will never visit this as switch statements are compiled into chained `if` statements.
    }
    
    /// Compiles a class declaration.
    public func visitClassDeclaration(stmt: ClassDeclStmt) throws {
        currentLocation = stmt.location
        
        // The class must be declared in the outermost scope (we don't allow nested classes).
        if scopeDepth > 0 {
            try error(message: "Nested classes are not permitted. Classes may only be declared globally.")
        }
        
        // Class names must be unique (since they're in the global namespace).
        if findClass(name: stmt.name) != nil {
            try error(message: "Redefined class `\(stmt.name)`.")
        }
        
        // We only allow classes to be declared at the top level of a script.
        if self.type != .topLevel {
            try error(message: "Classes can only be declared within the top level of a script.")
        }
        
        // Are we boot-strapping (i.e. compiling `Object` for the first time)?
        let bootstrapping = (stmt.name == "Object" && findClass(name: "Object") == nil ? true : false)
        
        // ================================
        // SUPERCLASS
        // ================================
        // We don't need to do this if we're compiling `Object` for the first time.
        var superclass: ClassData?
        var superclassName = stmt.superclass
        if !bootstrapping {
            if !stmt.hasSuperclass {
                // All classes (except for `Object`) implicitly inherit `Object`.
                superclassName = "Object"
            }
            
            // Check the superclass is valid and store a reference to it.
            if stmt.name == superclassName {
                try error(message: "A class cannot inherit from itself.")
            } else {
                superclass = findClass(name: superclassName!)
                if superclass == nil {
                    try error(message: "Class `\(stmt.name)` inherits class `\(superclassName!)` but there is no class with this name.")
                }
            }
        }
        
        // ================================
        // DECLARE THE CLASS
        // ================================
        // Store data about the class we're about to compile.
        currentClass = ClassData(declaration: stmt, superclass: superclass)
        knownClasses[stmt.name] = currentClass
        
        // Declare the class name as a global variable.
        try declareVariable(identifier: stmt.identifier, initialised: false, trackAsGlobal: true)
        
        // Add the name of the class to the function's constants table.
        let classNameIndex = try addConstant(value: .string(stmt.name))
        
        // Emit the "declare class" opcode. This will push the class on to the top of the stack.
        emitOpcode(.class_, location: stmt.location)
        
        // The first operand is the index of the name of the class.
        emitUInt16(value: UInt16(classNameIndex), location: stmt.location)
        
        // The second operand tells the VM if this is a foreign class (1) or not (0).
        emitByte(byte: stmt.isForeign ? 1 : 0)
        
        // The third operand is the total number of fields the class contains (for the entire hierarchy).
        // We don't know this yet so we will need to back-patch this with the actual number after we're
        // done compiling the methods and constructors.
        // For now, we'll emit the maximum number of permitted fields.
        emitByte(byte: 255)
        let numFieldsOffset = currentChunk.code.count - 1
        
        // The fourth operand is the index in `Klass.fields` of the first of *this* class's fields.
        // Earlier indexes are the fields of superclasses.
        // Strictly speaking, this is only needed for debug stepping in the VM but we'll emit it
        // even for production code to simplify the VM's implementation.
        // Classes are declared infrequently so I don't think this will have a meaningful performance penalty.
        emitByte(byte: UInt8(currentClass!.fieldStartIndex))
        
        // Define the class as a global variable.
        try defineVariable(index: classNameIndex)
        
        // Push the class on to the stack so the methods can find it.
        try emitVariableOpcode(shortOpcode: .getGlobal, longOpcode: .getGlobalLong, operand: classNameIndex, location: stmt.location)
        
        // ================================
        // INHERITANCE
        // ================================
        if !bootstrapping {
            // Look up the superclass by name and push it on to the top of the stack. Classes are always globally defined.
            try emitVariableOpcode(shortOpcode: .getGlobal, longOpcode: .getGlobalLong, operand: addConstant(value: .string(superclassName!)), location: stmt.location)
            
            // Tell the VM that this class inherits from the class on the top of the stack.
            // The VM will pop the superclass off the stack when its done handling the inheritance.
            emitOpcode(.inherit, location: stmt.location)
        }
        
        // Foreign instance methods.
        for (_, fm) in stmt.foreignInstanceMethods {
            try fm.accept(self)
        }
        
        // Foreign static methods.
        for (_, fm) in stmt.foreignStaticMethods {
            try fm.accept(self)
        }
        
        // Constructors.
        for constructor in stmt.constructors {
            try constructor.accept(self)
        }
        
        // Static methods.
        for (_, m) in stmt.staticMethods {
            try m.accept(self)
        }
        
        // Instance methods.
        for (_, m) in stmt.methods {
            try m.accept(self)
        }
        
        // Field count.
        if currentClass!.totalFieldCount > 255 {
            try error(message: "Class `\(stmt.name)` has exceeded the maximum number of fields (255). This includes inherited ones.")
        }
        
        // Disallow foreign classes from inheriting from classes with fields.
        // I'm doing this because Wren does and Bob Nystrom must have a good reason for this :)
        if stmt.isForeign && currentClass!.totalFieldCount > currentClass!.fieldCount {
            try error(message: "Foreign class `\(currentClass!.name)` cannot inherit from a class with fields.")
        }
        
        // Back-patch fields by replacing our placeholder with the actual number of fields for this class.
        currentChunk.code[numFieldsOffset] = UInt8(currentClass!.totalFieldCount)
        
        // ================================
        // DEBUGGING DATA
        // ================================
        if self.debugMode {
            // Tell the VM the name and index of all of this class's fields so we can see them in the debugger.
            // The first operand is the index of the field's name in the constant pool.
            // The second operand is the index of the field in `Klass.fields`.
            for (i, fieldName) in currentClass!.fields.enumerated() {
                let fieldNameIndex = try addConstant(value: .string(fieldName))
                emitOpcode(.debugFieldName)
                emitUInt16(value: UInt16(fieldNameIndex))
                emitByte(byte: UInt8(currentClass!.fieldStartIndex + i))
            }
        }
        
        // ================================
        // NOTHING EDGE CASE
        // ================================
        // We're compiling the built-in type `Nothing`.
        // Since the VM keeps just one instance of `Nothing`, we need to tell it to create it now that
        // the class has been defined.
        // There's a special instruction for that.
        if stmt.name == "Nothing" {
            emitOpcode(.defineNothing)
        }
        
        // Tidy up by popping the class off the stack.
        emitOpcode(.pop)
        
        // We're no longer compiling a class.
        currentClass = nil
    }
    
    /// Compiles a class constructor.
    ///
    /// To define a new constructor, the VM needs three things:
    ///  1. The constructor's argument count.
    ///  2. The function that is the constructor's body.
    ///  3. The class to bind the constructor to.
    public func visitConstructorDeclaration(stmt: ConstructorDeclStmt) throws {
        currentLocation = stmt.location
        
        if stmt.parameters.count > 255 {
            try error(message: "The maximum number of parameters for a constructor is 255.")
        }
        
        // Compile the body. We need a new compiler for this.
        let compiler = Compiler(coreLibrarySource: "")
        let body = try compiler.compile(name: "constructor", parameters: stmt.parameters, body: stmt.body, type: .constructor, currentClass: currentClass, isStaticMethod: false, debugMode: self.debugMode, shouldReset: true, enclosingCompiler: self)
        
        // Store the compiled constructor body as a constant in this function's constant table
        // and push it on to the stack.
        try emitConstant(value: .function(body))
        
        // Emit the "declare constructor" opcode. The operand is the argument count.
        emitOpcode8(opcode: .constructor, operand: UInt8(stmt.parameters.count), location: stmt.location)
    }
    
    /// Compiles a `continue` statement.
    public func visitContinue(stmt: ContinueStmt) throws {
        currentLocation = stmt.location
        
        if currentLoop == nil {
            try error(message: "Cannot use `continue` outside of a loop.")
        }
        
        // Since we'll be jumping out of the scope, make sure any locals in it are discarded first.
        try discardLocals(depth: currentLoop!.scopeDepth + 1)
        
        // Emit a jump back to the top of the current loop.
        try emitLoop(loopStart: currentLoop!.start)
    }
    
    /// Compiles a `do` loop.
    public func visitDo(stmt: DoStmt) throws {
        currentLocation = stmt.location
        
        startLoop()
        
        try loopBody(stmt.body)
        
        // Compile the condition.
        try stmt.condition.accept(self)
        
        try exitLoopIfTrue()
        
        try endLoop()
    }
    
    public func visitElseCase(stmt: ElseCaseStmt) throws {
        // The compiler doesn't visit this as switch statements are compiled into chained `if` statements.
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
