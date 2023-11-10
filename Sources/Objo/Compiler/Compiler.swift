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
    
    // MARK: - `ExprVisitor` protocol methods
    
    /// Compiles the assignment of a value to a variable.
    public func visitAssignment(expr: AssignmentExpr) throws {
        currentLocation = expr.location
        
        // Compile the value to be assigned.
        try expr.value.accept(self)
        
        try assignment(name: expr.name)
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
    
    /// The VM should produce a string literal.
    public func visitString(expr: StringLiteral) throws {
        currentLocation = expr.location
        
        // Store the string in the chunk's constant table.
        let index = currentChunk.addConstant(.string(expr.value))
        
        // Tell the VM to produce the constant at runtime.
        try emitVariableOpcode(shortOpcode: .constant, longOpcode: .constantLong, operand: index)
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
