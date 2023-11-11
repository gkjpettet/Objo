//
//  VM.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public class VM {
    // MARK: - Static properties
    
    /// The upper bounds of the API slot array. Limited to 255 arguments since the argument count for many opcodes is a single byte.
    private static let MAX_SLOTS = 255
    
    /// The upper bounds of the value stack.
    private static let MAX_STACK = 255
    
    /// The upper bounds of the callframe stack.
    private static let MAX_FRAMES = 64
    
    // MARK: - Event handlers
    
    /// The function that is called when the VM has finished execution.
    public var finished: (() -> Void)?
    
    /// The function that is called when the VM invoke's the `print()` function. The string to print is the argument.
    public var print: ((String) -> Void)?
    
    /// The function that is called when the VM is about to stop execution.
    ///
    /// `(scriptId, lineNumber) -> Void`
    public var willStop: ((Int, Int) -> Void)?
    
    // MARK: - Public properties
    
    /// The API slot array. Used to pass data between the VM and the host application.
    public var slots: [Value] = []
    
    /// If `true` then the VM is in low performance debug mode and can interact with chunks compiled in debug mode to provide debugging information.
    public var debugMode: Bool = false
    
    // MARK: - Private properties
    
    /// A reference to the built-in Boolean class. Will be nil whilst bootstrapping.
    private var booleanClass: Klass?

    /// Returns the chunk we're currently reading from.
    /// It's owned by the function whose call frame we're currently in.
    private var currentChunk: Chunk { return currentFrame.function.chunk }
    
    /// The current call frame.
    private var currentFrame: CallFrame {
        get { return frames.last! }
        set(newValue) { frames[frames.count - 1] = newValue }
    }
    
    /// The number of ongoing function calls.
    private var frameCount: Int { return frames.count }
    
    /// The call frame stack.
    private var frames: [CallFrame] = []
    
    /// Stores the VM's global variables. Key = variable name, value = variable value.
    private var globals: [String : Value] = [:]
    
    /// True if the VM is currently executing code.
    public var isRunning: Bool { return _isRunning }
    private var _isRunning = false
    
    /// A reference to the built-in KeyValue class. Will be nil whilst bootstrapping.
    private var keyValueClass: Klass?
    
    /// The call frame during the previous instruction. Used by the debugger.
    private var lastInstructionFrame: CallFrame?
    
    /// The line of code the VM last stopped on. Will be `-1` if the debugger has yet to begin.
    private var lastStoppedLine: Int = -1
    
    /// The id of the script the VM last stopped in. Will be `-1` for the standard library.
    private var lastStoppedScriptId: Int = -1
    
    /// A reference to the built-in List class. Will be nil whilst bootstrapping.
    private var listClass: Klass?
    
    /// A reference to the built-in Nothing class. Will be nil whilst bootstrapping.
    private var nothingClass: Klass?
    
    /// A reference to the built-in Number class. Will be nil whilst bootstrapping.
    private var numberClass: Klass?
    
    /// The singleton Random instance. Will be nil until first accessed through `Maths.random()`.
    private var randomInstance: Instance?
    
    /// If `true` then the VM should stop at the next opportunity (prior to the next instruction fetch).
    /// Only works when `debugMode == true`.
    private var shouldStop = false
    
    /// The VM's value stack.
    private var stack: [Value?] = []
    
    /// Points to the index in `stack` just past the element containing the top value. Therefore `0` means the stack is empty.
    /// It's the index the next value will be pushed to.
    private var stackTop: Int = 0
    
    /// A reference to the built-in String class. Will be nil whilst bootstrapping.
    private var stringClass: Klass?
    
    // MARK: - Public methods
    
    /// Initialises the VM and interprets the passed function.
    /// Use this to interpret a top level function.
    public func interpret(function: Function) throws {
        reset()
        
        // Push the function to run onto the stack as a runtime value.
        push(.function(function))
        
        // Call the passed function.
        try callFunction(function, argCount: 0)
        
        try run()
    }
    
    /// Resets the virtual machine.
    public func reset() {
        _isRunning = false
        
        // Initialise the value stack.
        stackTop = 0
        stack = Array(repeating: nil, count: VM.MAX_STACK * VM.MAX_FRAMES)
        
        // Initialise the call frame stack.
        frames = []
        
        /// API
        slots = Array(repeating: .nothing, count: VM.MAX_SLOTS)
        
        
        globals = [:]
        
        booleanClass = nil
        numberClass = nil
        stringClass = nil
        nothingClass = nil
        keyValueClass = nil
        listClass = nil
        randomInstance = nil
        
        // Debugger.
        lastInstructionFrame = nil
        lastStoppedLine = -1
        lastStoppedScriptId = -1
        shouldStop = false
    }
    
    /// Runs the interpreter.
    /// Assumes it's been initialised prior to this and has a valid call frame to execute.
    public func run(stepping: Bool = false) throws {      
        // Make sure we have a valid instruction pointer.
        if currentFrame.ip >= currentChunk.code.count {
            _isRunning = false
            return
        }
        
        _isRunning = true
        
        // This is the beating heart of the VM. **Everything** in this loop is speed critical.
        while true {
            
            // ===============================================================
            // STEP-DEBUGGING
            if debugMode && stepping && currentChunk.isDebug {
                if shouldStop {
                    _isRunning = false
                    willStop?(lastStoppedScriptId, lastStoppedLine)
                    return
                } else if try shouldBreak() {
                    _isRunning = false
                    willStop?(lastStoppedScriptId, lastStoppedLine)
                    return
                }
            }
            // ===============================================================
            
            let opcode = Opcode(rawValue: readByte())!
            switch opcode {
            case .add:
                if let (a, b) = stackTopAreNumbers() {
                    // Pop the stack and replace the top with the answer.
                    stack[stackTop - 2] = .number(a + b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "+(_)")
                }
                
            case.add1:
                // Increment the value on the top of the stack by 1.
                switch peek(0) {
                case .number(let d):
                    stack[stackTop - 1] = .number(d + 1)
                default:
                    push(.number(1))
                    try invokeBinary(signature: "+(_)")
                }
                
            case .assert:
                // Pop the message.
                let message: String = pop().description
                
                // Pop the condition off the stack. If it's false then raise a runtime error.
                if isFalsey(pop()) {
                    throw error(message: "Failed assertion: \(message)")
                }
                
            case.bitwiseAnd:
                if let (a, b) = stackTopAreNumbers() {
                    // Pop the stack and replace the top with the answer.
                    // Bitwise operators work on 32-bit unsigned integers
                    stack[stackTop - 2] = .number(Double(Int(a) & Int(b)))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "&(_)")
                }
                
            case.constant:
                push(readConstant())
                
            case .constantLong:
                push(readConstantLong())
                
            case.nothing:
                // a nothing literal.
                push(.nothing)
                
            case .pop:
                stackTop -= 1
                
            case .popN:
                // Pop N values off the stack. N is the single byte operand.
                stackTop = stackTop - Int(readByte())
                
            case .return_:
                // Pop the return value off the stack and put it in slot 0 of the API slots array so the host application can access it.
                slots[0] = pop()
                
                // Pop this callframe
                frames.removeLast()
                
                if frameCount == 0 {
                    // Exit the VM.
                    stackTop = 0
                    _isRunning = false
                    finished?()
                    return
                }
                
            default:
                throw error(message: "Opcode `\(String(describing: opcode))` not yet implemented.")
            }
        }
    }
    
    // MARK: - Private methods
    
    /// "Calls" a class. Essentially this creates a new instance.
    ///
    /// At the moment this method is called, the stack should look like this:
    /// |           <--- StackTop
    /// | argN
    /// | arg1
    /// | klass
    ///
    /// - Note: In my Xojo implementation this **doesn't** update `CurrentFrame`.
    private func callClass(_ klass: Klass, argCount: Int) throws {
        // Replace the class with a new blank instance of that class.
        stack[stackTop - argCount - 1] = .instance(Instance(klass: klass))
        
        // Invoke the constructor (if defined).
        var constructor: Function?
        if argCount < klass.constructors.count {
            constructor = klass.constructors[argCount]
        }
        
        // We allow a class to omit providing a default (zero parameter) constructor.
        if constructor == nil && argCount != 0 {
            throw error(message: "There is no \(klass.name)` constructor that expects \(argCount) argument\(argCount == 1 ? "" : "s").")
        }
        
        // If this is a foreign class, call the `allocate` callback so the host can do any additional setup needed.
        if klass.isForeign {
            let stackBase = stackTop - argCount - 1
            var arguments: [Value] = []
            for i in 1...argCount {
                arguments.append(stack[stackBase + i]!)
            }
            klass.foreignInstantiate?(self, &stack[stackBase]!, arguments)
        }
        
        // Invoke the constructor if defined.
        if constructor != nil {
            try callFunction(constructor!, argCount: argCount)
        }
    }
    
    /// Calls a foreign method.
    ///
    /// At this moment, the stack looks like this:
    ///
    /// |           <--- StackTop
    /// | argN
    /// | arg1
    /// | receiver

    private func callForeignMethod(_ fm: ForeignMethod, argCount: Int) throws {
        if argCount != fm.arity {
            throw error(message: "Expected \(fm.arity) arguments but got \(argCount).")
        }
        
        // Move the receiver and arguments from the stack to the API slots.
        // The receiver will always be in slot 0 with the arguments following in their declared order.
        // Note that the API slots array will contain nonsense data outside the bounds of the arguments.
        for i in stride(from: argCount, through: 0, by: -1) {
            slots[i] = pop()
        }
        
        // Push nothing on to the stack in case the method doesn't set a return value.
        push(.nothing)
        
        // Call the foreign method.
        fm.method(self)
    }
    
    /// Calls a compiled function.
    ///
    /// - Parameter argCount: The number of arguments that are on the stack for this function call. This is asserted.
    private func callFunction(_ function: Function, argCount: Int) throws {
        if argCount != function.arity {
            throw error(message: "Expected \(function.arity) arguments but got \(argCount).")
        }
        
        // Make sure we don't overflow with a deep call frame (most likely a user error with
        // a runaway recursive issue).
        if frameCount >= VM.MAX_FRAMES {
            throw error(message: "Stack overflow.")
        }
        
        // Setup the callframe to call.
        // The `-1` is to skip over local stack slot 0 which contains the function being called.
        frames.append(CallFrame(function: function, ip: 0, stackBase: stackTop - argCount - 1))
    }
    
    /// Performs a call on the passed value which expects to find `argCount` arguments on the call stack.
    private func  callValue(_ value: Value, argCount: Int) throws {
        switch value {
        case .klass(let k):
            try callClass(k, argCount: argCount)
            
        case .function(let f):
            try callFunction(f, argCount: argCount)
            
        case .boundMethod(let bm):
            // Put the receiver of the call (the instance before the dot) in slot 0 for the upcoming call frame.
            if bm.receiver is Klass {
                stack[stackTop - argCount - 1] = .klass(bm.receiver as! Klass)
            } else if bm.receiver is Instance {
                stack[stackTop - argCount - 1] = .instance(bm.receiver as! Instance)
            } else {
                throw error(message: "Expected the bound method's receiver to be either a Klass or an Instance.")
            }
            
            // Call the bound method.
            if bm.isForeign {
                try callForeignMethod(bm.method as! ForeignMethod, argCount: argCount)
            } else {
                try callFunction(bm.method as! Function, argCount: argCount)
            }
            
        case .foreignMethod(let fm):
            try callForeignMethod(fm, argCount: argCount)
            
        default:
            throw error(message: "Can only call functions, classes and methods.")
        }
    }
    
    /// Returns a VMError at the current IP (unless otherwise specified).
    private func error(message: String, offset: Int? = nil) -> VMError {
        let ip = offset ?? currentFrame.ip
        
        // Create a rudimentary stack trace.
        var stackTrace: [String] = []
        for frame in frames.reversed() {
            let function = frame.function
            let funcName = function.name == "*main*" ? "`<main>`" : "`\(function.name)`"
            stackTrace.append("[line \(function.chunk.lineForOffset(frame.ip - 1))] in \(funcName)")
        }
        
        return VMError(line: currentChunk.lineForOffset(ip), message: message, scriptId: currentChunk.scriptIDForOffset(ip), stackDump: stackDump(), stackTrace: stackTrace)
    }
    
    /// Invokes an overloaded binary operator method with `signature` on the
    /// callee (instance/class) and operand on the stack.
    ///
    /// Raises a VM error if the callee doesn't implement the overloaded operator.
    /// ```
    /// operand              <---- top of the stack
    /// callee to invoke on  <---- should be class/instance
    /// ```
    private func invokeBinary(signature: String) throws {
        guard let callee = peek(1) else {
            throw error(message: "Invalid stack index.")
        }
        
        switch callee {
        case .string:
            try invokeFromClass(klass: stringClass!, signature: signature, argCount: 1, isStatic: false)
            
        case .number:
            try invokeFromClass(klass: numberClass!, signature: signature, argCount: 1, isStatic: false)
            
        case .boolean:
            try invokeFromClass(klass: booleanClass!, signature: signature, argCount: 1, isStatic: false)
            
        case .instance(let i):
            try invokeFromClass(klass: i.klass, signature: signature, argCount: 1, isStatic: false)
            
        case .klass(let k):
            try invokeFromClass(klass: k, signature: signature, argCount: 1, isStatic: true)
            
        default:
            throw error(message: "\(callee) does not implement `\(signature)`.")
        }
    }
    
    /// Directly invokes a method with `signature` on `klass`. Assumes either `klass` or an instance
    /// of `klass` and the required arguments are already on the stack.
    /// Internally calls `callValue()`.
    ///
    /// |
    /// | argN <-- top of stack
    /// | arg1
    /// | instance or class
    private func invokeFromClass(klass: Klass, signature: String, argCount: Int, isStatic: Bool) throws {
        var method: Value?
        
        if isStatic {
            method = klass.staticMethods[signature]
            if method == nil {
                throw error(message: "There is no static method with signature `\(signature)` on `\(klass.name)`.")
            }
        } else {
            method = klass.methods[signature]
            if method == nil {
                throw error(message: "`\(klass.name)` instance does not implement `\(signature)`.")
            }
        }
        
        try callValue(method!, argCount: argCount)
    }
    
    /// Returns true if `v` is considered "falsey".
    ///
    /// Objo considers the boolean value `false` and the Objo value `nothing` to
    /// be false, everything else is true.
    private func isFalsey(_ value: Value) -> Bool {
        switch value {
        case .nothing:
            return true
            
        case .boolean(let b):
            return !b
            
        default:
            return false
        }
    }
    
    /// Returns `true` if `opcode` is worth stopping on.
    ///
    /// We stop on the following operations:
    /// Variable declarations, assignments, assertions, continue, exit, return
    private func isStoppableOpcode(_ opcode: Opcode) -> Bool {
        switch opcode {
        case .assert, .setLocal, .setGlobal, .setGlobalLong, .defineGlobal, .defineGlobalLong, .setField, .setStaticField, .setStaticFieldLong, .return_, .loop, .call, .invoke, .invokeLong, .breakpoint:
            return true
            
        default:
            return false
        }
    }
    
    /// Returns the value `distance` from the top of the stack.
    /// Leaves the value on the stack.
    /// A value of `0` would return the top item.
    private func peek(_ distance: Int) -> Value? {
        return stack[stackTop - distance - 1]
    }
    
    /// Pops a value off of the stack and returns it.
    private func pop() -> Value {
        stackTop -= 1
        return stack[stackTop]!
    }
    
    /// Pushes a value on to the stack.
    private func push(_ value: Value) {
        stack[stackTop] = value
        stackTop += 1
    }
    
    /// Reads the byte in `currentChunk` at the current `ip` and returns it.
    /// Increments the `ip`.
    private func readByte() -> UInt8 {
        currentFrame.ip += 1
        return currentChunk.readByte(offset: currentFrame.ip - 1)
    }
    
    /// Reads a constant from the chunk's constant pool using a single byte operand. Increments IP.
    private func readConstant() -> Value {
        return currentChunk.constants[Int(readByte())]!
    }
    
    /// Reads a constant from the chunk's constant pool using two byte operands. Increments IP.
    private func readConstantLong() -> Value {
        return currentChunk.constants[Int(readUInt16())]!
    }
    
    /// Reads two bytes from `currentChunk` at the current `ip` and returns them as a UInt16.
    /// Increments the IP by 2.
    private func readUInt16() -> Int {
        currentFrame.ip = currentFrame.ip + 2
        return Int(currentChunk.readUInt16(offset: currentFrame.ip - 2))
    }
    
    /// Returns `true` if the VM should break (exit its run loop) or `false` if it should continue.
    /// `true` indicates we've reached a sensible stopping point.
    private func shouldBreak() throws -> Bool {
        // Determine the line number and script ID that the VM is currently at.
        let frameLine = currentChunk.lineForOffset(currentFrame.ip)
        let frameScriptId = currentChunk.scriptIDForOffset(currentFrame.ip)
        
        // Disallow stopping within the standard library (scriptID -1).
        if frameScriptId == -1 {
            return false
        }
        
        // Don't stop again if we've already stopped on this exact line.
        if frameLine == lastStoppedLine && frameScriptId == lastStoppedScriptId {
            return false
        }
        
        // Get the instruction.
        guard let opcode = Opcode(rawValue: currentChunk.readByte(offset: currentFrame.ip)) else {
            throw error(message: "Invalid opcode at current offset.")
        }
        
        if lastInstructionFrame != currentFrame || isStoppableOpcode(opcode) {
            // We've reached a new source line on a stoppable opcode.
            lastStoppedLine = frameLine
            lastStoppedScriptId = frameScriptId
            lastInstructionFrame = currentFrame
            return true
        }
        
        return false
    }
    
    /// Returns a rudimentary stack dump.
    private func stackDump() -> String {
        var dump: [String] = []
        for i in 0..<stackTop {
            let item = stack[i]
            if item != nil {
                dump.append("[\(stack[i]!.description)]")
            } else {
                dump.append("[nil]")
            }
        }
        
        return dump.joined()
    }
    
    /// If the top two values on the stack are numbers then they are left in placd but their numeric values are returned as a tuple.
    /// Otherwise we return nil.
    /// The tuple is of the form `(a, b)` where `a` is below `b` on the stack.
    /// ```
    /// b
    /// a
    /// ```
    private func stackTopAreNumbers() -> (Double, Double)? {
        let a = stack[stackTop - 2]
        let b = stack[stackTop - 1]
        switch a {
        case .number(let aValue):
            switch b {
            case .number(let bValue):
                return (aValue, bValue)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
