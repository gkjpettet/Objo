//
//  CoreNothing.swift
//  
//
//  Created by Garry Pettet on 16/11/2023.
//
//  Implements the foreign methods for the Nothing class.

import Foundation

public struct CoreNothing {
    /// The user is calling the `Nothing` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The Nothing class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Nothing` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        // There are no static methods on the `Nothing` class.
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
    
    // MARK: - Private static functions
    
    /// Returns `true` since `nothing` is considered `false`.
    ///
    /// Assumes slot 0 is a nothing instance.
    ///
    /// `Nothing.not() -> boolean`
    private static func not(vm: VM) throws {
        vm.setReturn(.boolean(true))
    }
    
    /// Returns "nothing".
    ///
    /// Assumes slot 0 is a nothing instance.
    ///
    /// `Nothing.toString() -> string`
    private static func toString(vm: VM) throws  {
        vm.setReturn(.string("nothing"))
    }
}
