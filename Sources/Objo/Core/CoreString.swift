//
//  CoreString.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//
//  Provides the required foreign methods for Objo's String class.

import Foundation

public struct CoreString: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    /// Contains the instance methods defined for the String class. Key = signature, value = callback.
    private static let instanceMethods: [String : callback] = [
        "+(_)"              : add,
        "*(_)"              : multiply,
        "[_]"               : index,
        "codePoints()"      : codepoints,
        "contains(_)"       : contains,
        "count()"           : count,
        "endsWith(_)"       : endsWith,
        "endsWith(_,_)"     : endsWithCaseSensitivity,
        "indexOf(_)"        : indexOf,
        "indexOf(_,_)"      : indexOfStart,
        "indexOf(_,_,_)"    : indexOfCaseSensitivity,
        "iterate(_)"        : iterate,
        "iteratorValue(_)"  : iteratorValue,
        "left(_)"           : left,
        "lowercase()"       : lowercase,
        "middle(_)"         : middle,
        "middle(_,_)"       : middleLength,
        "replace(_,_)"      : replace,
        "replaceAll(_,_)"   : replaceAll,
        "right(_)"          : right,
        "split(_)"          : split,
        "startsWith(_)"     : startsWith,
        "startsWith(_,_)"   : startsWithCaseSensitivity,
        "titlecase()"       : titlecase,
        "trim()"            : trim,
        "trim(_)"           : trimChars,
        "trimEnd()"         : trimEnd,
        "trimEnd(_)"        : trimEndChars,
        "trimStart()"       : trimStart,
        "trimStart(_)"      : trimStartChars,
        "uppercase()"       : uppercase
    ]
    
    /// Contains the static methods defined for the String class. Key = signature, value = callback.
    private static let staticMethods: [String : callback] = [
        "fromCodepoint(_)"  : fromCodepoint
    ]
    
    // MARK - Public methods
    
    /// The user is calling the `String` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The String class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `String` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            return staticMethods[signature]
        } else {
            return instanceMethods[signature]
        }
    }
    
    // MARK: - Private methods
    
    /// Concatenates this string with the argument in slot 1 and returns the result.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is value to append.
    ///
    /// `String.+(other) -> string`
    private static func add(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't even happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
        }
        
        vm.setReturn(.string(this + vm.getSlot(1).description))
    }
    
    /// Returns a new string containing the UTF-8 encoding of `codepoint`.
    ///
    /// Expects slot 1 is an integer number.
    ///
    /// `String.fromCodepoint(codePoint) -> String`
    private static func fromCodepoint(vm: VM) throws {
        guard case .number(let codepoint) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `codepoint` argument should be a positive integer.")
            return
        }
        
        guard let codepoint = Int(exactly: codepoint) else {
            try vm.runtimeError(message: "The `codepoint` argument should be a positive integer")
            return
        }
        
        guard codepoint > 0 else {
            try vm.runtimeError(message: "The `codepoint` argument should be a positive integer")
            return
        }
        
        guard let scalar = Unicode.Scalar(codepoint) else {
            try vm.runtimeError(message: "Invalid codepoint `\(codepoint)`.")
            return
        }
        
        vm.setReturn(.string(String(Character(scalar))))
    }
    
    /// Returns the character at `index` in this string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot is `index` - a positive integer.
    /// `String.[index] -> string`
    private static func index(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .number(let index) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `index` argument must be a positive integer.")
            return
        }
        
        guard let index = Int(exactly: index) else {
            try vm.runtimeError(message: "The `index` argument must be a positive integer.")
            return
        }
        
        guard index >= 0 else {
            try vm.runtimeError(message: "The `index` argument must be a positive integer.")
            return
        }
        
        vm.setReturn(.string(this[index]))
    }
    
    /// Returns the position of the first occurrence of `other` inside this string or `-1` if not found. Case sensitive.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    ///
    /// `String.indexOf(other) -> number`
    private static func indexOf(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        vm.setReturn(.number(Double(this.indexOf(substring: other))))
    }
    
    /// Returns the position of `other` inside this string or `-1` if not found.
    /// Begins at index `start`.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    /// - Slot 2 is an integer number.
    /// String.indexOf(other, start) -> number
    private static func indexOfStart(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `other` argument must be a string.")
            return
        }
        
        guard case .number(let start) = vm.getSlot(2) else {
            try vm.runtimeError(message: "The `start` argument should be a number.")
            return
        }
        
        guard let start = Int(exactly: start) else {
            try vm.runtimeError(message: "The `start` argument should be a positive integer.")
            return
        }
        
        guard start >= 0 else {
            try vm.runtimeError(message: "The `start` argument should be a positive integer.")
            return
        }
        
        vm.setReturn(.number(Double(this.indexOf(substring: other, from: start))))
    }
    
    /// Returns the position of `other` inside this string or `-1` if not found.
    /// Begins at index `start`.
    /// The `caseSensitive` argument determines case sensitivity.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    /// - Slot 2 is an integer number.
    /// - Slot 3 is the `caseSensitive` argument.
    ///
    /// `String.indexOf(other, start, caseSensitive) -> number`
    private static func indexOfCaseSensitivity(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `other` argument must be a string.")
            return
        }
        
        guard case .number(let start) = vm.getSlot(2) else {
            try vm.runtimeError(message: "The `start` argument should be a number.")
            return
        }
        
        guard let start = Int(exactly: start) else {
            try vm.runtimeError(message: "The `start` argument should be a positive integer.")
            return
        }
        
        guard start >= 0 else {
            try vm.runtimeError(message: "The `start` argument should be a positive integer.")
            return
        }
        
        vm.setReturn(.number(Double(this.indexOf(substring: other, from: start, caseSensitive: VM.isTruthy(vm.getSlot(3))))))
    }
    
    /// Returns the a portion of this string beginning at index `start` until the end of the string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a number
    ///
    /// `String.middle(start) -> string`
    private static func middle(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .number(let start) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `start` argument must be a number.")
            return
        }
        
        guard let start = Int(exactly: start) else {
            try vm.runtimeError(message: "The `start` argument must be a postive integer.")
            return
        }
        
        vm.setReturn(.string(this.substring(fromIndex: start)))
    }
    
    /// Returns `length` characters beginning at `start` from this string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a number (start)
    /// - Slot 2 is a number (length)
    ///
    /// String.middle(start, length) -> string
    private static func middleLength(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .number(let start) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `start` argument must be a number.")
            return
        }
        
        guard let start = Int(exactly: start) else {
            try vm.runtimeError(message: "The `start` argument must be a postive integer.")
            return
        }
        
        guard case .number(let length) = vm.getSlot(2) else {
            try vm.runtimeError(message: "The `length` argument must be a number.")
            return
        }
        
        guard let length = Int(exactly: length) else {
            try vm.runtimeError(message: "The `length` argument must be a postive integer.")
            return
        }
        
        do {
            try vm.setReturn(.string(this.substring(start: start, length: length)))
        } catch ObjoError.invalidArgument {
            try vm.runtimeError(message: "Invalid arguments to `String.middle(start, length)`.")
        }
    }
}
