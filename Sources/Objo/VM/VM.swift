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
    
    /// The function that is called when defining a foreign class. The host should return the callback to use when a new class
    /// is instantiated.
    /// name of the class -> (VM, the instance being instantiated as a Value, the arguments to the constructor)
    public var bindForeignClass: ((String) -> (VM, Instance, [Value]) throws -> Void)?
    
    /// The function that is called when defining a foreign method. The host should return the callback to use whenever that foreign method is called. The signature for that callback always takes the VM as the argument and returns Void.
    // (className, signature, isStatic) -> (VM) -> Void
    public var bindForeignMethod: ((String, String, Bool) -> ((VM) throws -> Void))?
    
    /// The function that is called when the VM has finished execution.
    public var finished: (() -> Void)?
    
    /// The function that is called when the VM invoke's the `print()` function. The string to print is the argument.
    public var print: ((String) -> Void)?
    
    /// The function that is called when the VM is about to stop execution.
    ///
    /// `(scriptId, lineNumber) -> Void`
    public var willStop: ((Int, Int) -> Void)?
    
    // MARK: - Public properties
    
    /// If `true` then the VM is in low performance debug mode and can interact with chunks compiled in debug mode to provide debugging information.
    public var debugMode: Bool = false
    
    /// The VM's singleton instance of `nothing`. Will be nil whilst bootstrapping.
    private(set) var nothing: Nothing?
    
    /// The singleton `Random` instance. Will be nil until first accessed through `Maths.random()`.
    public var randomInstance: Instance?
    
    /// The API slot array. Used to pass data between the VM and the host application.
    public var slots: [Value?] = []
    
    // MARK: - Private properties
    
    /// A reference to the built-in Boolean class. Will be nil whilst bootstrapping.
    private(set) var booleanClass: Klass?

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
    private(set) var keyValueClass: Klass?
    
    /// The call frame during the previous instruction. Used by the debugger.
    private var lastInstructionFrame: CallFrame?
    
    /// The line of code the VM last stopped on. Will be `-1` if the debugger has yet to begin.
    private var lastStoppedLine: Int = -1
    
    /// The id of the script the VM last stopped in. Will be `-1` for the standard library.
    private var lastStoppedScriptId: Int = -1
    
    /// A reference to the built-in List class. Will be nil whilst bootstrapping.
    private(set) var listClass: Klass?
    
    /// A reference to the built-in Nothing class. Will be nil whilst bootstrapping.
    private(set) var nothingClass: Klass?
    
    /// A reference to the built-in Number class. Will be nil whilst bootstrapping.
    private(set) var numberClass: Klass?
    
    /// If `true` then the VM should stop at the next opportunity (prior to the next instruction fetch).
    /// Only works when `debugMode == true`.
    private var shouldStop = false
    
    /// The VM's value stack.
    private var stack: [Value?] = []
    
    /// Points to the index in `stack` just past the element containing the top value. Therefore `0` means the stack is empty.
    /// It's the index the next value will be pushed to.
    private var stackTop: Int = 0
    
    /// A reference to the built-in String class. Will be nil whilst bootstrapping.
    private(set) var stringClass: Klass?
    
    // MARK: - Public methods
    
    /// Returns a top-level variable named `name`.
    public func getVariable(name: String) -> Value? {
        return globals[name]
    }
    
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
    
    /// Creates and returns a new List instance with the optional items.
    public func newList(items: [Value]?) -> Instance {
        let list = Instance(klass: listClass!)
        list.foreignData = ListData(items: items)
        return list
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
        slots = Array(repeating: nil, count: VM.MAX_SLOTS)
        
        // The VM will set this once it has defined the `Nothing` class within the runtime.
        nothing = nil
        
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
                if VM.isFalsey(pop()) {
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
                
            case .bitwiseNot:
                switch stack[stackTop - 1] {
                case .number(let d):
                    // Do the "bitwise not" operation in place for speed.
                    stack[stackTop - 1] = .number(Double(~Int(d)))
                default:
                    try invokeUnary(signature: "~()")
                }
                
            case .bitwiseOr:
                if let (a, b) = stackTopAreNumbers() {
                    // Pop the stack and replace the top with the answer.
                    stack[stackTop - 2] = .number(Double(Int(a) | Int(b)))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "|(_)")
                }
                
            case .bitwiseXor:
                if let (a, b) = stackTopAreNumbers() {
                    // Pop the stack and replace the top with the answer.
                    stack[stackTop - 2] = .number(Double(Int(a) ^ Int(b)))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "^(_)")
                }
                
            case .breakpoint:
                // Allows the VM to pause at a manually set break point.
                // Has no effect in production chunks or if the VM is not in debug mode.
                if debugMode && currentChunk.isDebug {
                    lastStoppedLine = currentChunk.lineForOffset(currentFrame.ip - 1)
                    lastStoppedScriptId = currentChunk.scriptIDForOffset(currentFrame.ip - 1)
                    lastInstructionFrame = currentFrame
                    _isRunning = false
                    willStop?(lastStoppedScriptId, lastStoppedLine)
                    return
                }
                
            case .call:
                let argcount = Int(readByte())
                // Peek past the arguments to find the function to call.
                try callValue(peek(argcount)!, argCount: argcount)
                
            case .class_:
                let className = readConstantLong().description
                let isForeign = readByte() == 1
                let fieldCount = Int(readByte())
                let firstFieldIndex = Int(readByte())
                push(.klass(try newClass(name: className, isForeign: isForeign, fieldCount: fieldCount, firstFieldIndex: firstFieldIndex)))
                if isForeign {
                    try defineForeignClass()
                }
                
            case.constant:
                push(readConstant())
                
            case .constantLong:
                push(readConstantLong())
                
            case .constructor:
                try defineConstructor(argCount: Int(readByte()))
                
            case .debugFieldName:
                /// The compiler should have ensured that the field name to add to is on the top of the stack.
                guard case .string(let fieldName) = readConstantLong() else {
                    throw error(message: "Expected a field name on the top of the stack.")
                }
                try addFieldNameToClass(fieldName: fieldName, fieldIndex: Int(readByte()))
                
            case .defineGlobal:
                // The constants table index of the name of the global variable is on the top of the stack
                // and the value should be beneath it.
                guard case .string(let globalName) = readConstant() else {
                    throw error(message: "Expected, on the top of the stack, an index into the constants table for the name of the global to define.")
                }
                globals[globalName] = pop()
                
            case .defineGlobalLong:
                // The constants table index of the name of the global variable is on the top of the stack
                // and the value should be beneath it.
                guard case .string(let globalName) = readConstantLong() else {
                    throw error(message: "Expected, on the top of the stack, an index into the constants table for the name of the global to define.")
                }
                globals[globalName] = pop()
                
            case.defineNothing:
                defineNothing()
                
            case .divide:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(a / b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "/(_)")
                }
                
            case .equal:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a == b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "==(_)")
                }
                
            case .exit:
                throw error(message: "Unexpected `exit` placeholder instruction. The chunk is invalid.")
                
            case.false_:
                push(.boolean(false))
                
            case .foreignMethod:
                guard case .string(let signature) = readConstantLong() else {
                    throw error(message: "Expected an index to a signature on the top of the stack.")
                }
                try defineForeignMethod(signature: signature, arity: Int(readByte()), isStatic: readByte() == 1 ? true : false)
                
            case .getField:
                try getField(fieldIndex: Int(readByte()))
                
            case .getGlobal:
                guard case .string(let name) = readConstant() else {
                    throw error(message: "Expected an index to a global name on the top of the stack.")
                }
                try getGlobal(name: name)
                
            case .getGlobalLong:
                guard case .string(let name) = readConstantLong() else {
                    throw error(message: "Expected an index to a global name on the top of the stack.")
                }
                try getGlobal(name: name)
                
            case .getLocal:
                // The operand is the stack slot where the local variable lives.
                // Load the value at that slot and then push it on to the top of the stack.
                push(stack[currentFrame.stackBase + Int(readByte())]!)
                
            case .getLocalClass:
                // The operand is the stack slot where the local variable lives (should be an instance).
                // Load it and then push its class onto the stack.
                guard case .instance(let instance) = stack[currentFrame.stackBase + Int(readByte())] else {
                    throw error(message: "Expected an instance.")
                }
                push(.klass(instance.klass))
                
            case .getStaticField:
                guard case .string(let name) = readConstant() else {
                    throw error(message: "Expected an index to a static field name on the top of the stack.")
                }
                try getStaticField(name: name)
                
            case .getStaticFieldLong:
                guard case .string(let name) = readConstantLong() else {
                    throw error(message: "Expected an index to a static field name on the top of the stack.")
                }
                try getStaticField(name: name)
                
            case .greater:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a > b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: ">(_)")
                }
                
            case .greaterEqual:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a >= b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: ">=(_)")
                }
                
            case .inherit:
                try inherit()
                
            case .invoke:
                guard case .string(let signature) = readConstant() else {
                    throw error(message: "Expected an index to a signature on the top of the stack.")
                }
                try invoke(signature: signature, argCount: Int(readByte()))
                
            case .invokeLong:
                guard case .string(let signature) = readConstantLong() else {
                    throw error(message: "Expected an index to a signature on the top of the stack.")
                }
                try invoke(signature: signature, argCount: Int(readByte()))
                
            case .is_:
                try invokeBinary(signature: "is(_)")
                
            case .jump:
                // Unconditionally jump the specified offset from the current instruction pointer.
                // +2 accounts for the 2 bytes we read.
                currentFrame.ip += readUInt16() + 2
                
            case .jumpIfFalse:
                // Jump `offset` bytes from the current instruction pointer _if_ the value on the top of the stack is falsey.
                let offset = readUInt16()
                if VM.isFalsey(peek(0)!) {
                    currentFrame.ip += offset
                }
                
            case .jumpIfTrue:
                // Jump `offset` bytes from the current instruction pointer _if_ the value on the top of the stack is truthy.
                let offset = readUInt16()
                if VM.isTruthy(peek(0)!) {
                    currentFrame.ip += offset
                }
                
            case .keyValue:
                try newKeyValue()
                
            case .less:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a < b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "<(_)")
                }
                
            case .lessEqual:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a <= b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "<=(_)")
                }
                
            case .list:
                try newListLiteral(itemCount: Int(readByte()))
                
            case .load0:
                push(.number(0))
                
            case .load1:
                push(.number(1))
                
            case .load2:
                push(.number(2))
                
            case .loadMinus1:
                push(.number(-1))
                
            case .loadMinus2:
                push(.number(-2))
                
            case .localVarDeclaration:
                // The compiler has declared a new local variable. The first UInt16 operand is the index in the
                // constants table of the name of the variable declared. The second single byte operand is the
                // slot the local occupies.
                // The compiler should have already emitted `getLocal`.
                guard case .string(let variableName) = readConstantLong() else {
                    throw error(message: "Expected an index to a local variable name to be on the top of the stack.")
                }
                currentFrame.locals[variableName] = Int(readByte())
                
            case .logicalXor:
                let b = pop()
                let a = pop()
                push(.boolean(VM.isTruthy(a) != VM.isTruthy(b)))
                
            case .loop:
                // Unconditionally jump the specified offset back from the current instruction pointer.
                // +2 accounts for the 2 bytes we read.
                currentFrame.ip -= readUInt16() + 2
                
            case .map:
                try newMapLiteral(keyValueCount: Int(readByte()))
                
            case .method:
                guard case .string(let signature) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a signature on the top of the stack.")
                }
                try defineMethod(signature: signature, isStatic: readByte() != 0)
                
            case.modulo:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(a.truncatingRemainder(dividingBy: b))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "%(_)")
                }
                
            case .multiply:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(a * b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "*(_)")
                }
                
            case .negate:
                if case .number(let d) = peek(0) {
                    stack[stackTop - 1] = .number(-d)
                } else {
                    try invoke(signature: "-()", argCount: 0)
                }
                
            case .not:
                if case .boolean(let b) = stack[stackTop - 1] {
                    // "notting" a boolean is so common we'll implement it inline.
                    stack[stackTop - 1] = .boolean(!b)
                } else {
                    try invokeUnary(signature: "not()")
                }
                
            case .notEqual:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .boolean(a != b)
                    stackTop -= 1
                } else if case .boolean(let b1) = peek(0), case .boolean(let b2) = peek(1) {
                    stack[stackTop - 2] = .boolean(b1 != b2)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "<>(_)")
                }
                
            case.nothing:
                push(.instance(nothing!))
                
            case .pop:
                stackTop -= 1
                
            case .popN:
                // Pop N values off the stack. N is the single byte operand.
                stackTop = stackTop - Int(readByte())
                
            case .rangeExclusive:
                try invokeBinary(signature: "..<(_)")
                
            case .rangeInclusive:
                try invokeBinary(signature: "...(_)")
                
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
                
            case .setField:
                try setField(fieldIndex: Int(readByte()))
                
            case .setGlobal:
                guard case .string(let globalName) = readConstant() else {
                    throw error(message: "Expected a constants table index to a global variable's name on the top of the stack.")
                }
                self.globals[globalName] = peek(0)
                
            case .setGlobalLong:
                guard case .string(let globalName) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a global variable's name on the top of the stack.")
                }
                self.globals[globalName] = peek(0)
                
            case .setLocal:
                // The operand is the stack slot where the local variable lives.
                // Store the value at the top of the stack in the stack slot corresponding to the local variable.
                stack[currentFrame.stackBase + Int(readByte())] = peek(0)
                
            case .setStaticField:
                guard case .string(let fieldName) = readConstant() else {
                    throw error(message: "Expected a constants table index to a static field name on the top of the stack.")
                }
                try setStaticField(name: fieldName)
                
            case .setStaticFieldLong:
                guard case .string(let fieldName) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a static field name on the top of the stack.")
                }
                try setStaticField(name: fieldName)
                
            case .shiftLeft:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(Double(Int(a) << Int(b)))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "<<(_)")
                }
                
            case .shiftRight:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(Double(Int(a) >> Int(b)))
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: ">>(_)")
                }
                
            case .subtract:
                if let (a, b) = stackTopAreNumbers() {
                    stack[stackTop - 2] = .number(a - b)
                    stackTop -= 1
                } else {
                    try invokeBinary(signature: "-(_)")
                }
                
            case .subtract1:
                if case .number(let d) = peek(0) {
                    stack[stackTop - 1] = .number(d - 1)
                } else {
                    push(.number(1))
                    try invokeBinary(signature: "-(_)")
                }
                
            case .superConstructor:
                guard case .string(let superclassName) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a superclass name on the top of the stack.")
                }
                try superConstructor(superclassName: superclassName, argCount: Int(readByte()))
                
            case .superInvoke:
                guard case .string(let superclassName) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a superclass name on the top of the stack.")
                }
                
                guard case .string(let signature) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a signature name on the top of the stack.")
                }
                
                try superInvoke(superclassName: superclassName, signature: signature, argCount: Int(readByte()))
                
            case .superSetter:
                guard case .string(let superclassName) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a superclass name on the top of the stack.")
                }
                
                guard case .string(let signature) = readConstantLong() else {
                    throw error(message: "Expected a constants table index to a signature name on the top of the stack.")
                }
                
                try superInvoke(superclassName: superclassName, signature: signature, argCount: 1)
                
            case.swap:
                // Swap the two values on the top of the stack.
                // Do this in-place to avoid push/pop calls.
                //   b       a
                //   a  -->  b
                let tmp = stack[stackTop - 1]
                stack[stackTop - 1] = stack[stackTop - 2]
                stack[stackTop - 2] = tmp
                
            case .true_:
                push(.boolean(true))
            }
            
            // For step-debugging.
            lastInstructionFrame = currentFrame
            
            _isRunning = false
        }
    }
    
    /// Forces the VM to raise a runtime error at the current IP with the passed message.
    public func runtimeError(message: String) throws {
        throw error(message: message)
    }
    
    // MARK: - Public API
    
    /// Returns the value in the specified index in the slot array.
    public func getSlot(_ index: Int) -> Value {
        return slots[index]!
    }
    
    /// Sets the return value of a foreign method to the specified value.
    
    /// If you want to return `nothing` from a method you don't need to call this.
    /// Before a foreign method is called the VM has cleared the call frame stack and pushed nothing on to it.
    /// Setting a return value just requires us to replace the pushed nothing object with `value`.
    public func setReturn(_ value: Value) {
        stack[stackTop - 1] = value
    }
    
    // MARK: - Private methods
    
    /// Adds a named field to the class on the top of the stack.
    ///
    /// When the compiler is building a debuggable chunk, it will emit the names and indexes
    /// of all of a class' fields.
    private func addFieldNameToClass(fieldName: String, fieldIndex: Int) throws {
        // The compiler should have ensured that the class to add to is on the top of the stack.
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected a class to be on the top of the stack.")
        }
        
        klass.fields[fieldIndex] = fieldName
    }
    
    /// The VM is requesting the callback to use when instantiating a new foreign class.
    /// This method is called when the host application failed to provide one.
    /// We check our standard libraries.
    ///
    /// Returns `nil` if none defined.
    private func bindCoreForeignClass(className: String) throws -> ((VM, Instance, [Value]) throws -> Void)? {
        switch className {
        case "Boolean":
            return CoreBoolean.allocate
            
        case "KeyValue":
            return CoreKeyValue.allocate
            
        case "List":
            return CoreList.allocate
            
        case "Map":
            return CoreMap.allocate
            
        case "Maths":
            return CoreMaths.allocate
            
        case "Nothing":
            return CoreNothing.allocate
            
        case "Number":
            return CoreNumber.allocate
            
        case "Object":
            return CoreObject.allocate
            
        case "Random":
            return CoreRandom.allocate
            
        case "String":
            return CoreString.allocate
            
        case "System":
            return CoreSystem.allocate
            
        default:
            return nil
        }
    }
    
    /// The VM is requesting the callback to use when calling the specified foreign method on a class.
    /// The host application will have failed to provide one.
    /// We check our standard libraries.
    ///
    /// Returns `nil` if none defined.
    private func bindCoreForeignMethod(className: String, signature: String, isStatic: Bool) throws -> ((VM) throws -> Void)? {
        switch className {
        case "Boolean":
            return CoreBoolean.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "KeyValue":
            return CoreKeyValue.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "List":
            return CoreList.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Map":
            return CoreMap.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Maths":
            return CoreMaths.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Nothing":
            return CoreNothing.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Number":
            return CoreNumber.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Object":
            return CoreObject.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "Random":
            return CoreRandom.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "String":
            return CoreString.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        case "System":
            return CoreSystem.bindForeignMethod(signature: signature, isStatic: isStatic)
            
        default:
            return nil
        }
    }
    
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
            
            guard case .instance(let instance) = stack[stackBase] else {
                throw error(message: "Expected an instance on the stack at the stack base.")
            }
            try klass.foreignInstantiate?(self, instance, arguments)
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
        push(.instance(nothing!))
        
        // Call the foreign method.
        try fm.method(self)
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
    private func callValue(_ value: Value, argCount: Int) throws {
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
    
    /// Defines a constructor on the class just below the constructor's body on the stack.
    /// Will pop the constructor off the stack but leave the class in place.
    ///
    /// The constructor's body should be on the top of the stack with its class just beneath it:
    ///
    ///```
    ///                   <---- stack top
    /// constructor body
    /// class
    /// ```
    private func defineConstructor(argCount: Int) throws {
        guard case .function(let constructor) = pop() else {
            throw error(message: "Expected a constructor on the top of the stack.")
        }
        
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected a class to be beneath the constructor on the stack.")
        }
        
        // Constructors are stored on the class by arity.
        // Therefore `klass.constructors[0]` is a constructor with 0 arguments,
        // `klass.constructors[2]` is a constructor with 2 arguments, etc.
        klass.constructors[argCount] = constructor
    }
    
    /// Defines a foreign class. Assumes the class is already on the top of the stack.
    private func defineForeignClass() throws {
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected a class on the top of the stack but got `\(String(describing: peek(0)))`.")
        }
        
        // Ask the host application for the instantiation callback to use.
        klass.foreignInstantiate = bindForeignClass?(klass.name)
        
        if klass.foreignInstantiate == nil {
            // The host isn't aware of this class. Check if the core libraries have a callback for it.
            klass.foreignInstantiate = try bindCoreForeignClass(className: klass.name)
            if klass.foreignInstantiate == nil {
                throw error(message: "There is no foreign class instantiation callback for `\(klass.name)`.")
            }
        }
        
        // If this is one of Objo's built-in types we keep a reference to the class for use elsewhere.
        // This saves us having to look them up.
        // All the built-in types are foreign classes.
        switch klass.name {
        case "Boolean":
            booleanClass = klass
            
        case "KeyValue":
            keyValueClass = klass
            
        case "List":
            listClass = klass
            
        case "Nothing":
            nothingClass = klass
            
        case "Number":
            numberClass = klass
            
        case "String":
            stringClass = klass
            
        default:
            break
        }
    }
    
    /// Defines a foreign method with `signature` and `arity` on the class on the top of the stack.
    private func defineForeignMethod(signature: String, arity: Int, isStatic: Bool) throws {
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected a class on the top of the stack.")
        }
        
        // Ask the host for the callback to use. This overrides any specified by the core libraries.
        var callback = bindForeignMethod?(klass.name, signature, isStatic)
        if callback == nil {
            // The host application doesn't have a callback for us. Check if the core libraries do.
            callback = try bindCoreForeignMethod(className: klass.name, signature: signature, isStatic: isStatic)
            if callback == nil {
                throw error(message: "The host application failed to return a foreign method callback for `\(klass.name).\(signature)`.")
            }
        }
        
        // Create the foreign method.
        let fm = ForeignMethod(signature: signature, arity: arity, uuid: UUID(), method: callback!)
        
        if isStatic {
            klass.staticMethods[signature] = .foreignMethod(fm)
        } else {
            klass.methods[signature] = .foreignMethod(fm)
        }
    }
    
    /// Defines a method with `signature` on the class just below the method's body on the stack.
    /// Pops the method off the stack but leaves the class in place.
    ///
    /// The method's body should be on the top of the stack with its class just beneath it:
    ///
    /// ```
    /// method
    /// class
    /// ```
    private func defineMethod(signature: String, isStatic: Bool) throws {
        guard case .function(let method) = pop() else {
            throw error(message: "Expected a method on the top of the stack.")
        }
        
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected a class on the top of the stack.")
        }
        
        if isStatic {
            klass.staticMethods[signature] = .function(method)
        } else {
            klass.methods[signature] = .function(method)
        }
    }
    
    /// The compiler has just defined the `Nothing` class and left it on the top of the stack for us.
    /// Create our single instance of Nothing for use throughout the VM.
    ///
    /// We'll leave the Nothing class on the stack - the compiler will instruct us to
    /// pop it off for us momentarily.
    private func defineNothing() {
        nothing = Nothing(klass: nothingClass!)
        // When the VM started we had to initialise the stack with nil values (since `nothing` had not yet
        // been defined). Let's fix that now by replacing any nil entries in the stack with nothing.
        // We should only ever have to do this once (when nothing is defined in the core library).
        for i in 0...stack.count - 1 {
            if stack[i] == nil {
                stack[i] = .instance(nothing!)
            }
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
    
    /// Retrieves the value of an instance field at `fieldIndex` from the instance currently
    /// on the top of the stack and then pushes it on to the top of the stack.
    private func getField(fieldIndex: Int) throws {
        // Since instance fields can only be retrieved from within a method,
        // `this` should be in the method callframe's slot 0.
        guard case .instance(let instance) = stack[currentFrame.stackBase] else {
            if case .klass = stack[currentFrame.stackBase] {
                throw error(message: "You cannot access an instance field from a static method.")
            } else {
                throw error(message: "Only instances have fields")
            }
        }
        
        guard instance.klass != nothingClass else {
            throw error(message: "The `nothing` class does not have fields.")
        }
        
        // Get the value of the field from the instance and push it on to the stack.
        push(instance.fields[fieldIndex])
    }
    
    /// Reads the value of a global variable named `name` and pushes it on to the stack.
    /// Raises a runtime error if the global variable doesn't exist.
    private func getGlobal(name: String) throws {
        guard let value = globals[name] else {
            throw error(message: "Undefined variable `\(name)`.")
        }
        
        push(value)
    }
    
    /// Retrieves the value of a static field named `name` on the instance or class currently
    /// on the top of the stack and then pushes it on to the top of the stack.
    private func getStaticField(name: String) throws {
        // The compiler guarantees that static fields can only be retrieved from within an instance
        // method/constructor or a static method. Therefore, we will assume that
        // either `this` or the class will should be in the method callframe's slot 0.
        let receiver: Klass
        switch stack[currentFrame.stackBase] {
        case .instance(let instance):
            receiver = instance.klass
        case .klass(let klass):
            receiver = klass
        default:
            throw error(message: "Only classes and instances have static fields.")
        }
        
        // Get the value of the static field from the receiver.
        var value = receiver.staticFields[name]
        
        // If the static field doesn't exist then we create it.
        if value == nil {
            receiver.staticFields[name] = .instance(nothing!)
            value = .instance(nothing!)
        }
        
        push(value!)
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
    
    /// Invokes a unary operator overloaded method with `signature` on the
    /// instance/class on the top of the stack.
    ///
    /// Raises a VM runtime error if the instance/class doesn't implement the overloaded operator.
    /// value   <---- top of the stack
    private func invokeUnary(signature: String) throws {
        switch peek(0) {
        case .number:
            try invokeFromClass(klass: numberClass!, signature: signature, argCount: 0, isStatic: false)
            
        case .string:
            try invokeFromClass(klass: stringClass!, signature: signature, argCount: 0, isStatic: false)
            
        case .boolean:
            try invokeFromClass(klass: booleanClass!, signature: signature, argCount: 0, isStatic: false)
            
        case .instance(let i):
            try invokeFromClass(klass: i.klass, signature: signature, argCount: 0, isStatic: false)
            
        case .klass(let k):
            try invokeFromClass(klass: k, signature: signature, argCount: 0, isStatic: true)
            
        default:
            throw error(message: "\(String(describing: peek(0))) does not implement `\(signature)`.")
        }
    }
    
    /// Handles the `inherit` instruction.
    ///
    /// The compiler ensures that the stack looks like this when a class declaration specifies
    /// the class has a superclass.
    ///
    ///```
    /// | superclass  <-- top of the stack.
    /// | subclass
    /// ```
    private func inherit() throws {
        guard case .klass(let superclass) = peek(0) else {
            throw error(message: "Can only inherit from other classes.")
        }
        
        guard case .klass(let subclass) = peek(1) else {
            throw error(message: "Expected to find a subclass on the stack.")
        }
        
        // At this point, no methods have been defined on the subclass (since this
        // instruction should only occur within a class declaration). Therefore, copy all the
        // superclass's methods to the class on the stack.
        // NB: We don't inherit static methods or constructors **unless** the immediate
        // superclass is `Object`. In this case, we inherit the static methods.
        // This allows `Object` to provide static operator overloads.
        // CHECK: In Xojo we have to clone the dictionaries but I think there are value types
        subclass.methods = superclass.methods
        
        if superclass.name == "Object" {
            // CHECK: In Xojo we have to clone the dictionaries but I think there are value types
            subclass.staticMethods = superclass.staticMethods
        }
        
        // This class should keep a reference to its superclass.
        subclass.superclass = superclass
        
        // Pop the superclass off the stack.
        pop()
    }
    
    /// Invokes a method on an instance of a class. The receiver containing the method should be on the stack
    /// along with any arguments it requires.
    ///
    /// ```
    /// | argN <-- top of stack
    /// | arg1
    /// | instance/class
    /// ```
    private func invoke(signature: String, argCount: Int) throws {
        // Query the receiver from the stack. It should be beneath any arguments to the invocation.
        // We therefore peek `argCount` distance from the top.
        
        let klass: Klass
        var isStatic = false // Assume the method is directly on the instance.
        switch stack[stackTop - argCount - 1] {
        case .number:
            klass = numberClass!
            
        case .string:
            klass = stringClass!
            
        case .klass(let k):
            klass = k
            isStatic = true // This is actually a static method invocation.
            
        case .instance(let instance):
            klass = instance.klass
            
        case .boolean:
            klass = booleanClass!
            
        default:
            throw error(message: "Only classes and instances have methods.")
        }
        
        try invokeFromClass(klass: klass, signature: signature, argCount: argCount, isStatic: isStatic)
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
    
    /// Creates and returns a new class.
    private func newClass(name: String, isForeign: Bool, fieldCount: Int, firstFieldIndex: Int) throws -> Klass {
        let klass = Klass(vm: self, name: name, isForeign: isForeign, fieldCount: fieldCount, firstFieldIndex: firstFieldIndex)
        
        // All classes (except `Object`, obviously) inherit Object's static methods.
        if klass.name != "Object" {
            guard let objectValue = globals["Object"] else {
                throw error(message: "Cannot create a new class because the global `Object` has not been defined.")
            }
            
            switch objectValue {
            case .klass(let object):
                klass.staticMethods = object.staticMethods
            default:
                throw error(message: "There is a global variable named `Object` but it is not a class.")
            }
        }
        
        return klass
    }
    
    /// Creates a new `KeyValue` instance. The compiler should have placed the key and value on the stack
    /// with the `KeyValue` class beneath them.
    ///
    /// ```
    /// key             <-- top of the stack
    /// value
    /// KeyValue class
    /// ```
    private func newKeyValue() throws {
        guard case .klass(let kvClass) = peek(2) else {
            throw error(message: "Expected the KeyValue class beneath two constructor arguments.")
        }
        try callClass(kvClass, argCount: 2)
        
        // Read the key and value and wrap in a tuple.
        let data = (key: pop(), value: pop())
        
        // The top of the stack will now be a `KeyValue` instance. Set it's foreign data.
        guard case .instance(let kvInstance) = stack[stackTop - 1] else {
            // This really shouldn't happen since `callClass()` put the instance where it should be...
            throw error(message: "`callClass()` failed to put a KeyValue instance on the top of the stack.")
        }
        kvInstance.foreignData = data
        
        // Update the current callframe (since `callClass()` doesn't do this for us) and
        // we have invoked an actual constructor.
        frames.removeLast()
    }
    
    /// Creates a new list literal. The compiler will have placed the `List` class on the stack
    /// and any initial elements above this.
    private func newListLiteral(itemCount: Int) throws {
        // Pop and store any optional initial elements.
        var items: [Value] = []
        for _ in 1...itemCount {
            items.insert(pop(), at: 0)
        }
        
        // Call the default `List` constructor.
        guard case .klass(let listClass) = peek(0) else {
            throw error(message: "Expected the List class to be on the top of the stack.")
        }
        try callClass(listClass, argCount: 0)
        
        // The top of the stack will now be a `List` instance.
        // Add the initial elements to it's foreign data.
        guard case .instance(let listInstance) = stack[stackTop - 1] else {
            // This really shouldn't happen since `callClass()` put the instance where it should be...
            throw error(message: "`callClass()` failed to put a List instance on the top of the stack.")
        }
        listInstance.foreignData = items
    }
    
    /// Creates a new `Map` instance. The compiler will have placed the `Map` class on the stack
    /// and any initial key-value pairs above this.
    private func newMapLiteral(keyValueCount: Int) throws {
        // Pop and store any optional initial key-values.
        // These are compiled so the key is above the value on the stack.
        var keyValues: [Value : Value] = [:]
        for _ in 1...keyValueCount {
            keyValues[pop()] = pop()
        }
        
        guard case .klass(let klass) = peek(0) else {
            throw error(message: "Expected to find the `Map` class on the top of the stack.")
        }
        
        // Call the zero argument `Map` constructor.
        try callClass(klass, argCount: 0)
        
        // The top of the stack will now be a `Map` instance.
        guard case .instance(let mapInstance) = stack[stackTop - 1] else {
            throw error(message: "Expected a `Map` instance on the top of the stack.")
        }
        
        // Set the instance's foreign data to the key-values we popped off the stack.
        mapInstance.foreignData = keyValues
    }
    
    /// Returns the value `distance` from the top of the stack.
    /// Leaves the value on the stack.
    /// A value of `0` would return the top item.
    private func peek(_ distance: Int) -> Value? {
        return stack[stackTop - distance - 1]
    }
    
    /// Pops a value off of the stack and returns it.
    @discardableResult private func pop() -> Value {
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
    
    /// Sets the field at `fieldIndex` on the instance that is one from the top of
    /// the stack to the value on the top of the stack.
    ///
    /// ```
    /// |
    /// | ValueToAssign   <-- top of the stack
    /// | Instance        <-- the instance that should have the field at `fieldIndex`.
    /// |
    /// ````

    private func setField(fieldIndex: Int) throws {
        // Since fields can only be set from within a method, the compiler should have
        // ensured that `this` is in the method callframe's slot 0 (`stackBase`).
        guard case .instance(let instance) = stack[currentFrame.stackBase] else {
            if case .klass = stack[currentFrame.stackBase] {
                throw error(message: "You cannot set an instance field from a static method.")
            } else {
                throw error(message: "Only instances have fields.")
            }
        }
        
        guard instance.klass != nothingClass else {
            throw error(message: "You cannot set fields on `nothing`.")
        }
        
        // Set the field to the value on the top of the stack and pop it off.
        let value = pop()
        instance.fields[fieldIndex] = value
        
        // Push the value back on the stack (since this is an expression).
        push(value)
    }
    
    /// Sets a static field named `name` on the class (or instance's class) that is one from the top of the
    /// stack to the value on the top of the stack.
    ///
    /// ```
    /// |
    /// | ValueToAssign       <-- top of the stack
    /// | class or instance   <-- should have the static field named `name`.
    /// |
    /// ```
    private func setStaticField(name: String) throws {
        // The compiler guarantees that static fields can only be set from within a method or constructor
        // so we can safely assume that `this` will be in the
        // method callframe's slot 0 (`stackBase`).
        let receiver: Klass
        let tmp = stack[currentFrame.stackBase]
        if case .klass(let klass) = tmp {
            receiver = klass
        } else if case .instance(let instance) = tmp {
            receiver = instance.klass
        } else {
            throw error(message: "Only classes and instances have static fields.")
        }
        
        // Set the static field to the value on the top of the stack and pop it off.
        // If the static field has never been assigned to before then we create it.
        let value = pop()
        receiver.staticFields[name] = value
        
        // Push the value back on the stack (since this is an expression).
        push(value)
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
        let aValue = stack[stackTop - 2]
        let bValue = stack[stackTop - 1]
        
        guard case .number(let a) = aValue else {
            return nil
        }
        
        guard case .number(let b) = bValue else {
            return nil
        }
        
        return (a, b)
    }
    
    /// Invokes the specified superclass constructor on an instance. The instance should be on the stack
    /// along with any arguments it requires.
    ///
    /// ```
    /// |
    /// | argN <-- top of stack
    /// | arg1
    /// | instance
    /// ```
    private func superConstructor(superclassName: String, argCount: Int) throws {
        // Get the superclass. Since classes are all declared in the top level, it should be in `globals`.
        // The compiler will have checked that the superclass exists during compilation.
        guard case .klass(let superclass) = globals[superclassName] else {
            throw error(message: "There is no superclass named `\(superclassName)` defined in the global environment.")
        }
        
        // Call the correct constructor.
        // The compiler will have guaranteed that the superclass has a constructor with the correct arity.
        try callFunction(superclass.constructors[argCount]!, argCount: argCount)
    }
    
    /// Invokes the specified method on the superclass of the instance on the stack.
    /// The required arguments should also be on the stack.
    ///
    /// ```
    /// |
    /// | argN <-- top of stack
    /// | arg1
    /// | instance
    /// ```
    private func superInvoke(superclassName: String, signature: String, argCount: Int) throws {
        // Get the superclass. Since classes are all declared in the top level, it should be in `globals`.
        // The compiler will have checked that the superclass exists during compilation.
        guard case .klass(let superclass) = globals[superclassName] else {
            throw error(message: "There is no superclass named `\(superclassName)` defined in the global environment.")
        }
        
        // Call the correct method.
        // The compiler will have guaranteed that the superclass has a method with this signature.
        try callValue(superclass.methods[signature]!, argCount: argCount)
    }
    
    // MARK: - Static methods
    
    /// Returns true if `v` is considered "falsey".
    ///
    /// Objo considers the boolean value `false` and the Objo value `nothing` to
    /// be false, everything else is true.
    public static func isFalsey(_ value: Value) -> Bool {
        switch value {
        case .instance(let instance):
            return instance.klass.name == "Nothing"
            
        case .boolean(let b):
            return !b
            
        default:
            return false
        }
    }
    
    /// Returns True if `value` is *not* considered "falsey".
    ///
    /// Objo considers the boolean value `false` and the Objo value `nothing` to
    /// be false, everything else is true.
    public static func isTruthy(_ value: Value) -> Bool {
        switch value {
        case .boolean(let b):
            return b
            
        case .instance(let i):
            return i.klass.name != "Nothing"
            
        default:
            return true
        }
    }
}
