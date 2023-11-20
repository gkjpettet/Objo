//
//  CoreNumber.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//
//  Implements the foreign methods required for the Number class.

import Foundation

public struct CoreNumber: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    // MARK: - Properties
    
    /// Contains the instance methods defined for the Number class. Key = signature, value = callback.
    private static let instanceMethods: [String : callback] = [
        "+(_)"          : add,
        "<(_)"          : less,
        "<=(_)"         : lessEqual,
        ">(_)"          : greater,
        ">=(_)"         : greaterEqual,
        "..<(_)"        : rangeExclusive,
        "...(_)"        : rangeInclusive,
        "abs()"         : abs_,
        "acos()"        : acos_,
        "asin()"        : asin_,
        "atan()"        : atan_,
        "ceil()"        : ceil_,
        "cos()"         : cos_,
        "exp()"        : exp_,
        "floor()"       : floor_,
        "log()"         : log_,
        "isInteger()"   : isInteger,
        "max(_)"        : max_,
        "min(_)"        : min_,
        "pow(_)"        : pow_,
        "round()"       : round_,
        "sign()"        : sign_,
        "sqrt()"        : sqrt_,
        "sin()"         : sin_,
        "tan()"         : tan_,
        "toString()"    : toString
    ]
    
    /// Contains the static methods defined for the Number class. Key = signature, value = callback.
    private static let staticMethods: [String : callback] = [
        "fromString(_)" : fromString
    ]
    
    // MARK: - Public methods
    
    /// The user is calling the `Number` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The Number class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Number` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            return staticMethods[signature]
        } else {
            return instanceMethods[signature]
        }
    }
    
    // MARK: - Private methods
    
    /// Returns the absolute value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.abs() -> Number`
    private static func abs_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(abs(this)))
    }
    
    /// Returns the arc cosine value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.acos() -> Number`
    private static func acos_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(acos(this)))
    }
    
    /// Converts this number to a string and adds a value to it.
    ///
    /// `Number` + `Number` is handled within the VM for performance reasons.
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    ///
    /// `Number.+(value) -> string`
    private static func add(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen...
            try vm.runtimeError(message: "Expected a Number in slot 0.")
            return
        }
        
        vm.setReturn(.string(String(this) + vm.getSlot(1).description))
    }
    
    /// Returns the arc sine value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.asin() -> Number`
    private static func asin_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(asin(this)))
    }
    
    /// Returns the arc tangent value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.atan() -> Number`
    private static func atan_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(atan(this)))
    }
    
    /// Returns the value specified rounded up to the nearest whole number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.ceil() -> Number`
    private static func ceil_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(ceil(this)))
    }
    
    /// Returns the cosine value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.cos() -> Number`
    private static func cos_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(cos(this)))
    }
    
    /// Returns the exponential e (Euler’s number) raised to the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.exp() -> Number`
    private static func exp_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(exp(this)))
    }
    
    /// Returns the value rounded down to the nearest integer.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.floor() -> Number`
    private static func floor_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(floor(this)))
    }
    
    /// Attempts to parse `value` as a decimal literal and return it as an instance of `Number`.
    /// If the number cannot be parsed then `nothing` will be returned.
    ///
    /// It's a runtime error if `value` is not a string.
    /// The Number class will be in slot 0.
    /// `value` will be in slot 1
    ///
    /// `Number.fromString>(value) -> Number`
    private static func fromString(vm: VM) throws {
        guard case .string(let value) = vm.getSlot(1) else {
            try vm.runtimeError(message: "Expected a string argument to `Number.fromString(_)`.")
            return
        }
        
        guard let result = Double(value) else {
            try vm.runtimeError(message: "`value` cannot be parsed into a number.")
            return
        }
        
        vm.setReturn(.number(result))
    }
    
    /// Returns `true` if this is > `other`.
    ///
    /// Number < Number is handled within the VM for performance reasons.
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    ///
    /// `Number.>(other) -> boolean`
    private static func greater(vm: VM) throws {
        // Since this is handled in the VM, we'll just raise a runtime error. If we don't do this,
        // The VM will spit out an error saying that `Number` doesn't implement `>(_)`. It obviously
        // does so this is cleaner.
        try vm.runtimeError(message: "Both operands must be numbers.")
    }
    
    /// Returns `true` if this is >= `other`.
    ///
    /// Number < Number is handled within the VM for performance reasons.
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    ///
    /// `Number.>=(other) -> boolean`
    private static func greaterEqual(vm: VM) throws {
        // Since this is handled in the VM, we'll just raise a runtime error. If we don't do this,
        // The VM will spit out an error saying that `Number` doesn't implement `>=(_)`. It obviously
        // does so this is cleaner.
        try vm.runtimeError(message: "Both operands must be numbers.")
    }
    
    /// Returns `true` if this number is an integer.
    ///
    /// Since this is a built-in type, slot 0 will be a double.
    /// `Number.isInteger() -> boolean`
    private static func isInteger(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This shouldn't happen...
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.boolean(Int(exactly: this) != nil))
    }
    
    /// Returns `true` if this is < `other`.
    ///
    /// Number < Number is handled within the VM for performance reasons.
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    ///
    /// `Number.<(other) -> boolean`
    private static func less(vm: VM) throws {
        // Since this is handled in the VM, we'll just raise a runtime error. If we don't do this,
        // The VM will spit out an error saying that `Number` doesn't implement `<(_)`. It obviously
        // does so this is cleaner.
        try vm.runtimeError(message: "Both operands must be numbers.")
    }
    
    /// Returns `true` if this is <= `other`.
    ///
    /// Number < Number is handled within the VM for performance reasons.
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    ///
    /// `Number.<=(other) -> boolean`
    private static func lessEqual(vm: VM) throws {
        // Since this is handled in the VM, we'll just raise a runtime error. If we don't do this,
        // The VM will spit out an error saying that `Number` doesn't implement `<=(_)`. It obviously
        // does so this is cleaner.
        try vm.runtimeError(message: "Both operands must be numbers.")
    }
    
    /// Returns the maximum value when comparing this number and `other`.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// Slot 1 should be a number.
    /// `Number.max(other) -> Number`
    private static func max_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        guard case .number(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument to `max(_)` should be a number.")
            return
        }
        
        vm.setReturn(.number(max(this, other)))
    }
    
    /// Returns the minimum value when comparing this number and `other`.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// Slot 1 should be a number.
    /// `Number.min(other) -> Number`
    private static func min_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        guard case .number(let other) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument to `min(_)` should be a number.")
            return
        }
        
        vm.setReturn(.number(min(this, other)))
    }
    
    /// Raises this number (the base) to `power`. Returns nan if the base is negative.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// Slot 1 should be a number.
    /// `Number.pow(power) -> Number`
    private static func pow_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        guard case .number(let power) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The argument to `pow(_)` should be a number.")
            return
        }
        
        vm.setReturn(.number(pow(this, power)))
    }
    
    /// Returns the natural logarithm of the value specified.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.log() -> Number`
    private static func log_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(log(this)))
    }
    
    /// Returns a list with elements ranging from this number to `upper` (exclusive).
    ///
    /// Since this is a built-in type, slot 0 will be a double.
    /// `Number ..< upper -> List`
    private static func rangeExclusive(vm: VM) throws {
        guard case .number(let lower) = vm.getSlot(0) else {
            // This should never happen...
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        // Assert that the upper argument is a number.
        guard case .number(var upper) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The upper bounds must be a number.")
            return
        }
        
        var values: [Value] = []
        if lower == upper {
            // Empty array
        } else {
            if upper > lower {
                upper -= 1
                let value = lower
                while value <= upper {
                    values.append(.number(value))
                }
            } else { // lower > upper
                upper += 1
                var value = lower
                while value >= upper {
                    values.append(.number(value))
                    value -= 1
                }
            }
        }
        
        // Return a new list with the computed values.
        vm.setReturn(.instance(vm.newList(items: values)))
    }
    
    /// Returns a list with elements ranging from this number to `upper` (inclusive).
    ///
    /// Since this is a built-in type, slot 0 will be a double.
    /// `Number...upper -> List`
    private static func rangeInclusive(vm: VM) throws {
        guard case .number(let lower) = vm.getSlot(0) else {
            // This should never happen...
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        // Assert that the upper argument is a number.
        guard case .number(let upper) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The upper bounds must be a number.")
            return
        }
        
        var values: [Value] = []
        if lower == upper {
            values.append(.number(lower))
        } else if upper > lower {
            var value = lower
            while value <= upper {
                values.append(.number(value))
                value += 1
            }
        } else { // lower > upper
            var value = lower
            while value >= upper {
                values.append(.number(value))
                value -= 1
            }
        }
        
        // Return a new list with the computed values.
        vm.setReturn(.instance(vm.newList(items: values)))
    }
    
    /// Returns the value rounded to the nearest integer.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.round() -> Number`
    private static func round_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(round(this)))
    }
    
    /// Returns the sign of the number, expressed as a -1 or 1 for negative and positive numbers.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.sign() -> double`
    private static func sign_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(this.sign == .plus ? 0 : -1))
    }
    
    /// Returns the sine value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.sin() -> Number`
    private static func sin_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(sin(this)))
    }
    
    /// Returns the square root of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.sqrt() -> Number`
    private static func sqrt_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(sqrt(this)))
    }
    
    /// Returns the tangent value of the number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.tan() -> Number`
    private static func tan_(vm: VM) throws {
        guard case .number(let this) = vm.getSlot(0) else {
            // This should never happen.
            try vm.runtimeError(message: "Expected a number in slot 0.")
            return
        }
        
        vm.setReturn(.number(tan(this)))
    }
    
    /// Returns a string representation of this number.
    ///
    /// Since this is a built-in type, slot 0 will be a double (not an instance object).
    /// `Number.toString() -> string`
    private static func toString(vm: VM) throws {
        vm.setReturn(.string(vm.getSlot(0).description))
    }
}
