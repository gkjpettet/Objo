//
//  CoreBoolean.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//
//  Implements the foreign methods for the Boolean class.

import Foundation

public struct CoreBoolean: CoreType {
    /// The user is calling the `Boolean` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The Boolean class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Boolean` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        // All methods on `Boolean` are instance methods.
        if isStatic {
            return nil
        }
        
        switch signature {
        case "not()":
            return not
            
        case "toString()":
            return toString
            
        default:
            return nil
        }
    }
    
    /// Returns the logical complement of the value.
    ///
    /// Assumes slot 0 is a Boolean instance.
    ///
    /// `Boolean.not() -> boolean`
    private static func not(vm: VM) throws {
        guard case .boolean(let value) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Boolean instance in slot 0.")
            return
        }
        
        vm.setReturn(.boolean(!value))
    }
    
    private static func toString(vm: VM) throws {
        vm.setReturn(.string(vm.getSlot(0).description))
    }
}
