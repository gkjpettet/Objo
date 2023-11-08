//
//  Compiler.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

import Foundation

public class Compiler {
    
    // MARK: - Private properties.
    
    /// The abstract syntax tree this compiler is compiling.
    private var ast: [Stmt]
    
    /// The time take for the last compilation took.
    private var compileTime: TimeInterval?
    
    /// Optional data about the class currently being compiled. Will be nil if the compiler isn't currently compiling a class.
    private var currentClass: ClassData?
    
    private var currentChunk: Chunk {
        get { return self.function.chunk }
        set(newValue) { self.function.chunk = newValue }
    }
    
    /// The token the compiler is currently compiling.
    private var currentLocation: Token
    
    /// The current innermost loop being compiled, or `nil` if not in a loop.
    private var currentLoop: LoopData?
    
    /// If `true` then the compiler will output debug-quality bytecode.
    private var debugMode: Bool
    
    /// `true` if this compiler is compiling a static method.
    private var isStaticMethod = false
    
    /// Contains the names of every global variable declared as the key. Only the outermost compiler keeps track of declared variables. Child compilers, add new globals to the outermost parent. Therefore this may be empty even if there are known globals.
    /// Key = global name, Value = Bool (unused, set to `false`).
    private(set) var knownGlobals: [String : Bool]
    
    /// The classes already compiled by the compiler. Key = class name.
    private(set) var knownClasses: [String : ClassData]
    
    /// The local variables that are in scope.
    private(set) var locals: [LocalVariable]
    
    /// This compiler's internal parser.
    private var parser: Parser
    
    /// The time taken for the last parsing phase.
    private var parseTime: TimeInterval?
    
    /// The current scope depth. 0 = global scope.
    private var scopeDepth: Int = 0
    
    /// Used to track the compilation time.
    private var stopWatch: Stopwatch = Stopwatch()
    
    /// This compiler's internal lexer.
    private var tokeniser: Tokeniser
    
    /// The time taken for the last tokenising phase.
    private var tokeniseTime: TimeInterval?
    
    /// The tokens this compiler is compiling. May be empty if the compiler was instructed to compile an AST directly.
    private var tokens: [Token]
    
    // MARK: - Public properties
    
    /// This compiler's optional enclosing compiler. Needed as compilers can call other compilers to compile functions, methods, etc.
    public var enclosing: Compiler?
    
    /// The function currently being compiled.
    public var function: Function
    
    /// The type of function currently being compiled.
    public var type: FunctionType = .topLevel
    
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
            stmt.accept(self)
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
        
        return function
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
        
        
        // TODO: Finish implementing.
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
        currentChunk.writeOpcode(opcode, token: location ?? currentLocation)
    }
    
    /// Appends an opcode (UInt8) and an 8-bit operand to the current chunk at the current location.
    /// An optional `location` can be provided otherwise the compiler defaults to its current location.
    /// Assumes `operand` can be represented by a single byte.
    private func emitOpcode8(opcode: Opcode, operand: UInt8, location: Token? = nil) {
        let loc: Token = location ?? currentLocation
        currentChunk.writeOpcode(opcode, token: loc)
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
        currentChunk.writeUInt16(value, location: location ?? currentLocation)
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
        if function.chunk.code.count == 0 {
            
            // We've just compiled an empty function.
            emitReturn(location: location)
            
        } else if function.chunk.code.last! != Opcode.return_.rawValue {
            
            // The function's last instruction was *not* a return statement.
            emitReturn(location: location)
            
        }
    }
    
    /// Throws a `CompilerError` at the current location.
    /// If the error is not at the current location, `location` may be passed instead.
    private func error(message: String, location: Token? = nil) throws {
        throw CompilerError(message: message, location: location ?? currentLocation)
    }
}
