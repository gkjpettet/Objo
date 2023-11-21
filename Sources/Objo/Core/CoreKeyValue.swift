//
//  CoreKeyValue.swift
//
//
//  Created by Garry Pettet on 20/11/2023.
//
//  A KeyValue instance's foreign data will be a `KeyValueData` struct.

import Foundation

public struct CoreKeyValue: CoreType {
    
    // MARK: - Public methods
    
    /// The user is calling the `KeyValue` class constructor.
    ///
    /// `constructor()`
    /// `constructor(key, value)`
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        switch arguments.count {
        case 0:
            instance.foreignData = KeyValueData(key: .instance(vm.nothing!), value: .instance(vm.nothing!))
            
        case 2:
            instance.foreignData = KeyValueData(key: arguments[0], value: arguments[1])
            
        default:
            try vm.runtimeError(message: "Invalid number of arguments (expected 0 or 2, got \(arguments.count).)")
        }
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `KeyValue` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            // All methods on `KeyValue` are instance methods.
            return nil
        }
        
        switch signature {
        case "key()":
            return getKey
            
        case "key=(_)":
            return setKey
            
        case "value()":
            return getValue
            
        case "value=(_)":
            return setValue
            
        case "toString()":
            return toString
            
        default:
            return nil
        }
    }
    
    // MARK: - Private static methods
    
    /// Returns the key.
    ///
    /// `KeyValue.key() -> value`
    private static func getKey(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a KeyValue instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? KeyValueData else {
            try vm.runtimeError(message: "Expected a KeyValue instabnce in slot 0.")
            return
        }
        
        vm.setReturn(data.key)
    }
    
    /// Returns the value.
    ///
    /// `KeyValue.value() -> value`
    private static func getValue(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a KeyValue instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? KeyValueData else {
            try vm.runtimeError(message: "Expected a KeyValue instance in slot 0.")
            return
        }
        
        vm.setReturn(data.value)
    }
    
    /// Returns this key-value as a string ("key : value").
    ///
    /// `KeyValue.toString() -> string`
    private static func toString(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a KeyValue instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? KeyValueData else {
            try vm.runtimeError(message: "Expected a KeyValue instance in slot 0.")
            return
        }
        
        let s = data.key.description + " : " + data.value.description
        
        vm.setReturn(.string(s))
    }
}
