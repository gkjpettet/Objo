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
        "trimEnd()"         : trimEnd,
        "trimStart()"       : trimStart,
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
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(this + vm.getSlot(1).description))
    }
    
    /// Returns true if `other` is a substring of this string. Case-sensitive comparison.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    /// `String.contains(other) -> boolean`
    private static func contains(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        vm.setReturn(.boolean(this.contains(other)))
    }
    
    /// Returns the number of characters in the string.
    ///
    /// `String.count() -> number`
    private static func count(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.number(Double(this.count)))
    }
    
    /// Returns `true` if this string ends with `suffix`. **Case sensitive**.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    ///
    /// `String.endsWith(suffix) -> boolean`
    private static func endsWith(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let suffix) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        vm.setReturn(.boolean(this.hasSuffix(suffix)))
    }
    
    /// Returns `true` if this string ends with `suffix`. The `caseSensitive` argument determines case-sensitivity.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    /// - Slot 2 is the `caseSensitive` argument
    ///
    /// `String.endsWith(suffix, caseSensitive) -> boolean`
    private static func endsWithCaseSensitivity(vm: VM) throws  {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let suffix) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        if VM.isTruthy(vm.getSlot(2)) {
            // Case sensitive.
            vm.setReturn(.boolean(this.hasSuffix(suffix)))
        } else {
            // Case insensitive.
            vm.setReturn(.boolean(this.lowercased().hasSuffix(suffix.lowercased())))
        }
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
    
    /// Returns the first `count` characters from this string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a number
    ///
    /// `String.left(count) -> string`
    ///
    /// If `count` is greater than the length of the string then a runtime error occurs.
    private static func left(vm: VM) throws {
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        // Assert `count` is a positive integer.
        guard case .number(let count) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `count` argument should be a number.")
            return
        }
        
        guard let count = Int(exactly: count) else {
            try vm.runtimeError(message: "The `count` argument must be a positive integer.")
            return
        }
        
        guard count >= 0 else {
            try vm.runtimeError(message: "The `count` argument must be a positive integer.")
            return
        }
        
        guard count <= s.length else {
            try vm.runtimeError(message: "The `count` argument is out of bounds (\(count).")
            return
        }
        
        vm.setReturn(.string(String(s.prefix(count))))
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
    
    /// Returns `false` if there are no more characters to iterate or returns the index in the string
    /// of the next character.
    ///
    /// Assumes:
    /// - Slot 0 is a string.
    /// - Slot 1 is the `iter` argument.
    ///
    /// if `iter` is nothing then we should return 0 or false if an empty string.
    /// `iter` should be the index in the string of the previous character.
    /// Assumes slot 0 contains a string.
    ///
    /// `String.iterate(iter) -> number or false`
    private static func iterate(vm: VM) throws {
        // Get the string and precompute its last valid index
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        let sLastIndex = s.length - 1
        
        let iter = vm.getSlot(1)
        switch iter {
        case .instance(let i):
            if i.klass.name == "Nothing" {
                if s == "" {
                    vm.setReturn(.boolean(false))
                } else {
                    vm.setReturn(.number(0))
                }
            } else {
                try vm.runtimeError(message: "The iterator must be a positive integer.")
            }

        case .number(let iterNum):
            guard let index = Int(exactly: iterNum) else {
                try vm.runtimeError(message: "The iterator must be a positive integer.")
                return
            }
            guard index >= 0 else {
                try vm.runtimeError(message: "The iterator must be a positive integer.")
                return
            }
            
            // Return the next index or false if there are no more characters.
            if index >= sLastIndex {
                vm.setReturn(.boolean(false))
            } else {
                vm.setReturn(.number(Double(index + 1)))
            }
            
        default:
            try vm.runtimeError(message: "The iterator must be a positive integer.")
        }
    }
    
    /// Returns the next iterator value.
    ///
    /// Assumes:
    /// - Slot 0 is a string.
    /// - Slot 1 is an integer.
    ///
    /// Uses `iter` to determine the next value in the iteration. It should be an index into the string.
    ///
    /// `String.iteratorValue(iter) -> value`
    private static func iteratorValue(vm: VM) throws {
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .number(let iter) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The iterator must be a number.")
            return
        }
        
        guard let index = Int(exactly: iter) else {
            try vm.runtimeError(message: "The iterator must be a positive integer.")
            return
        }
        
        guard index >= 0 else {
            try vm.runtimeError(message: "The iterator must be a positive integer.")
            return
        }
     
        vm.setReturn(.string(s[index]))
    }
    
    /// Returns a lowercase version of this string.
    ///
    /// `String.lowercase() -> string`
    private static func lowercase(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(this.lowercased()))
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
    
    /// Returns a new string that contains this string repeated `count` times.
    ///
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is the `count` argument.
    ///
    /// `String.*(count) -> string`
    private static func multiply(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        // It's a runtime error if count is not a positive integer.
        guard case .number(let count) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `String.*(_)` method expects a positive integer argument.")
            return
        }
        
        guard let count = Int(exactly: count) else {
            try vm.runtimeError(message: "The `String.*(_)` method expects a positive integer argument.")
            return
        }
        
        guard count >= 0 else {
            try vm.runtimeError(message: "The `String.*(_)` method expects a positive integer argument.")
            return
        }
        
        vm.setReturn(.string(String(repeating: this, count: count)))
    }
    
    /// Replaces the first occurrence of `what` in this string with `with`.
    /// Case-sensitive.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is `what` (the string to search for)
    /// - Slot 2 is `with` (the replacement string)
    ///
    /// `String.replace(what, with) -> string`
    private static func replace(vm: VM) throws {
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let what) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `what` argument must be a string.")
            return
        }
        
        guard case .string(let with) = vm.getSlot(2) else {
            try vm.runtimeError(message: "The `with` argument must be a string.")
            return
        }
        
        if let range = s.range(of: what) {
            vm.setReturn(.string(s.replacingCharacters(in: range, with: with)))
        } else {
            // Not found. Just push the original string.
            vm.setReturn(.string(s))
        }
    }
    
    /// Replaces all occurrences of `what` in this string with `with`.
    /// Case-sensitive.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is `what` (the string to search for)
    /// - Slot 2 is `with` (the replacement string)
    ///
    /// `String.replaceAll(what, with) -> string`
    private static func replaceAll(vm: VM) throws {
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let what) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `what` argument must be a string.")
            return
        }
        
        guard case .string(let with) = vm.getSlot(2) else {
            try vm.runtimeError(message: "The `with` argument must be a string.")
            return
        }
        
        vm.setReturn(.string(s.replacingOccurrences(of: what, with: with)))
    }
    
    /// Returns the last `count` characters from this string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a number
    ///
    /// `String.right(count) -> string`
    ///
    /// If `count` is greater than the length of the string then a runtime error occurs.
    private static func right(vm: VM) throws {
        guard case .string(let s) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        // Assert `count` is a positive integer.
        guard case .number(let count) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `count` argument should be a number.")
            return
        }
        
        guard let count = Int(exactly: count) else {
            try vm.runtimeError(message: "The `count` argument must be a positive integer.")
            return
        }
        
        guard count >= 0 else {
            try vm.runtimeError(message: "The `count` argument must be a positive integer.")
            return
        }
        
        guard count <= s.length else {
            try vm.runtimeError(message: "The `count` argument is out of bounds (\(count).")
            return
        }
        
        vm.setReturn(.string(String(s.suffix(count))))
    }
    
    /// Returns a list of one or more strings separated by `separator`.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    ///
    /// `String.split(separator) -> list`
    private static func split(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let separator) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        let columns = this.components(separatedBy: separator)
        
        var items: [Value] = []
        for column in columns {
            items.append(.string(column))
        }
        vm.setReturn(.instance(vm.newList(items: items)))
    }
    
    /// Returns `true` if this string starts with `prefix`. **Case sensitive**.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    ///
    /// `String.startsWith(prefix) -> boolean`
    private static func startsWith(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let prefix) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        vm.setReturn(.boolean(this.hasPrefix(prefix)))
    }
    
    /// Returns `true` if this string starts with `prefix`. The `caseSensitive` argument determines case-sensitivity.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    /// - Slot 1 is a string.
    /// - Slot 2 is the `caseSensitive` argument
    ///
    /// `String.startsWith(prefix, caseSensitive) -> boolean`
    private static func startsWithCaseSensitivity(vm: VM) throws  {
        guard case .string(let this) = vm.getSlot(0) else {
            // Shouldn't ever happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        guard case .string(let prefix) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument must be a string.")
            return
        }
        
        if VM.isTruthy(vm.getSlot(2)) {
            // Case sensitive.
            vm.setReturn(.boolean(this.hasPrefix(prefix)))
        } else {
            // Case insensitive.
            vm.setReturn(.boolean(this.lowercased().hasPrefix(prefix.lowercased())))
        }
    }
    /// Returns a titlecase version of this string.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    ///
    /// `String.titlecase() -> string`
    
    private static func titlecase(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(this.capitalized))
    }
    
    /// Returns this string with whitespace removed from the beginning and end.
    ///
    /// Assumes:
    /// - Slot 0 is a string
    ///
    /// `String.trim() -> string`
    private static func trim(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(this.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    
    /// Returns this string with whitespace removed from the end.
    ///
    /// `String.trimEnd() -> string`
    private static func trimEnd(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(String(this.trailingSpacesTrimmed)))
    }
    
    /// Returns this string with whitespace removed from the beginning.
    ///
    /// `String.trimStart() -> string`
    private static func trimStart(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        let trimmed = String(this.drop(while: { $0.isWhitespace }))
        
        vm.setReturn(.string(trimmed))
    }
    
    /// Returns an uppercase version of this string.
    ///
    /// `String.uppercase() -> string`
    private static func uppercase(vm: VM) throws {
        guard case .string(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a string in slot 0.")
            return
        }
        
        vm.setReturn(.string(this.uppercased()))
    }
}
