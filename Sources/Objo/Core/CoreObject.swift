//
//  CoreObject.swift
//
//
//  Created by Garry Pettet on 15/11/2023.
//
//  Implements the foreign methods defined on the Object class.

import Foundation

public struct CoreObject {
    
    // MARK: - Public static functions
    
    /// The user is calling the `Object` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The Object class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Object` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            // STATIC METHODS
            switch signature {
            case "==(_)":
                return equalStatic
                
            case "<>(_)":
                return notEqualStatic
                
            case "hasMethod(_)":
                return hasMethodStatic
                
            case "is(_)":
                return is_
                
            default:
                return nil
            }
        } else {
            // INSTANCE METHODS
            switch signature {
            case "==(_)":
                return equalInstance
                
            case "<>(_)":
                return notEqual
                
            case "is(_)":
                return is_
                
            case "hasMethod(_)":
                return hasMethodInstance
                
            case "superType()":
                return superType
                
            case "toString()":
                return toString
                
            case "type()":
                return type_
                
            default:
                return nil
            }
        }
    }
    
    /// Compares two objects using built-in equality. This compares value types by value
    /// and all other objects are compared by reference: two objects are equal only if they are the exact
    /// same object.
    ///
    /// Assumes:
    /// - Slot 0 is a double/string/boolean, an instance or a class.
    /// - Slot 1 is a double/string/boolean, an instance or a class.
    ///
    /// Object.==(other) -> boolean
    public static func equalInstance(vm: VM) throws {
        vm.setReturn(.boolean(valuesEqual(vm.getSlot(0), vm.getSlot(1))))
    }
    
    /// Returns true if this object (or a superclass) implements an instance method with `signature`.
    ///
    /// Assumes:
    /// - Slot 0 is a boolean/number/string or instance.
    /// - Slot 1 is a string signature.
    ///
    /// Object.hasMethod(signature) -> boolean
    public static func hasMethodInstance(vm: VM) throws {
        let obj: Value = vm.getSlot(0)
        
        // The `signature` argument must be a string.
        guard case .string(let signature) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`Object.hasMethod(_)` expects a string argument.")
        }
        
        // Get the object's class so we can query its methods.
        let klass: Klass
        switch obj {
        case .boolean:
            klass = vm.booleanClass!
            
        case .number:
            klass = vm.numberClass!
            
        case .string:
            klass = vm.stringClass!
            
        case .instance(let instance):
            klass = instance.klass
            
        default:
            try vm.runtimeError(message: "Value `\(obj.description)` has an unknown class.")
        }
        
        vm.setReturn(.boolean(klass.methods[signature] != nil))
    }
    
    /// Compares two objects using built-in equality. This compares value types by value
    /// and all other objects are compared by reference: two objects are equal only if they are the exact
    /// same object.
    ///
    /// Assumes slots 0 and 1 are the values to compare.
    ///
    /// Object.<>(other) -> boolean
    public static func notEqual(vm: VM) throws {
        vm.setReturn(.boolean(!(valuesEqual(vm.getSlot(0), vm.getSlot(1)))))
    }
    
    /// Returns a default representation of the object as a string.
    ///
    /// Assumes:
    /// - Slot 0 is a boolean/double/string or instance.
    ///
    /// Object.toString() -> string
    public static func toString(vm: VM) throws {
        let obj = vm.getSlot(0)
        
        switch obj {
        case .instance(let instance):
            vm.setReturn(.string(instance.klass.name + " instance"))
            
        default:
            vm.setReturn(.string(obj.description))
        }
    }
    
    //  MARK: - Private static functions
    
    /// Returns `true` if this object's class or one of its superclasses is `other`.
    ///
    /// Assumes slots 0 and 1 are the values to compare.
    ///
    /// Object.is(other) -> boolean
    private static func is_(vm: VM) throws {
        let this = vm.getSlot(0)
        let other = vm.getSlot(1)
        
        // TODO: Finish implementing.
    }
    
    /// Returns true if `a` and `b` are considered equal.
    ///
    /// Compares two objects using built-in equality. This compares value types by value
    /// and all other objects are compared by reference: two objects are equal only if they are the exact
    /// same object.
    private static func valuesEqual(_ aValue: Value, _ bValue: Value) -> Bool {
        // Both booleans?
        if case .boolean(let a) = aValue, case .boolean(let b) = bValue {
            return a == b
        }
        
        // Both numbers?
        if case .number(let a) = aValue, case .number(let b) = bValue {
            return a == b
        }
        
        // Both strings?
        if case .string(let a) = aValue, case .string(let b) = bValue {
            return a == b
        }
        
        // Both instances?
        if case .instance(let a) = aValue, case .instance(let b) = bValue {
            // TODO: Handle key values.
            return a == b
        }
        
        // Both classes?
        if case.klass(let a) = aValue, case .klass(let b) = bValue {
            return a.name == b.name
        }
        
        return false
    }
}
