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
    
    /// The token the compiler is currently compiling.
    private var currentLocation: Token?
    
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
        function = Function(name: name, parameters: parameters, isSetter: false, debugMode: debugMode)
        
        if self.type != .topLevel {
            beginScope()
            
            // Compile the parameters.
            if parameters.count > 255 {
                try error(message: "Functions cannot have more than 255 parameters.")
            }
            
            for param in parameters {
                declareVariable(identifier: param, initialised: false, trackAsGlobal: false)
                defineVariable(index: 0) // The index value doesn't matter as the parameters are local.
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
        
        scopeDepth = 0
        
        stopWatch.reset()
        compileTime = 0
        
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
    
    /// Internally called when the compiler is finished.
    /// The compiler needs to implictly return an appropriate value if the user did not explictly specify one.
    private func endCompiler(location: Token) {
        if function.chunk.code.count == 0 {
            
            // We've just compiled an empty function.
            emitReturn(location: location)
            
        } else if function.chunk.code.last! != Opcode.return_ {
            
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
