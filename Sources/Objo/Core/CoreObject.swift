//
//  CoreObject.swift
//
//
//  Created by Garry Pettet on 15/11/2023.
//
//  Implements the foreign methods defined on the Object class.

import Foundation

public struct CoreObject: CoreType {
    
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
    
    //  MARK: - Private static functions
    
    /// Returns `true` if `klass` is of `type`. Walks the class hierarchy if necessary.
    private static func classIsOfType(klass: Klass, type: String) -> Bool {
        if klass.name == type {
            return true
        }
        
        var parent = klass.superclass
        while parent != nil {
            if parent!.name == type {
                return true
            } else {
                parent = parent!.superclass
            }
        }
        
        return false
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
    private static func equalInstance(vm: VM) throws {
        vm.setReturn(.boolean(valuesEqual(vm.getSlot(0), vm.getSlot(1))))
    }
    
    /// Compares this object's class with `other`.
    ///
    /// Assumes slot 0 is `this` class and slot 1 is `other`.
    ///
    /// `static Object.==(other) -> boolean`
    private static func equalStatic(vm: VM) throws {
        guard case .klass(let thisClass) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a class to be in slot 0.")
            return
        }
        
        switch vm.getSlot(1) {
        case .klass(let otherClass):
            vm.setReturn(.boolean(classIsOfType(klass: thisClass, type: otherClass.name)))
            
        case .string(let otherString):
            vm.setReturn(.boolean(classIsOfType(klass: thisClass, type: otherString)))
            
        default:
            vm.setReturn(.boolean(false))
        }
    }
    
    /// Compares this object's class with `other`.
    ///
    /// Assumes slot 0 is `this` class and slot 1 is `other`.
    ///
    /// `static Object.<>(other) -> boolean`
    private static func notEqualStatic(vm: VM) throws  {
        guard case .klass(let thisClass) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Epxected a class to be in slot 0.")
            return
        }
        
        switch vm.getSlot(1) {
        case .klass(let otherClass):
            vm.setReturn(.boolean(!classIsOfType(klass: thisClass, type: otherClass.name)))
            
        case .string(let otherString):
            vm.setReturn(.boolean(!classIsOfType(klass: thisClass, type: otherString)))
            
        default:
            vm.setReturn(.boolean(true))
        }
    }
    
    /// Returns true if this object (or a superclass) implements an instance method with `signature`.
    ///
    /// Assumes:
    /// - Slot 0 is a boolean/number/string or instance.
    /// - Slot 1 is a string signature.
    ///
    /// `Object.hasMethod(signature) -> boolean`
    private static func hasMethodInstance(vm: VM) throws {
        let obj: Value = vm.getSlot(0)
        
        // The `signature` argument must be a string.
        guard case .string(let signature) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`Object.hasMethod(_)` expects a string argument.")
            return
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
            return
        }
        
        vm.setReturn(.boolean(klass.methods[signature] != nil))
    }
    
    /// Returns `true` if this object (or a superclass) implements a static method with `signature`.
    ///
    /// Assumes:
    /// - Slot 0 is a class.
    /// - Slot 1 is a string signature.
    ///
    /// `Object.hasMethod(signature) -> boolean`
    private static func hasMethodStatic(vm: VM) throws {
        guard case .klass(let thisClass) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a class.")
            return
        }
        
        guard case .string(let signature) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`Object.hasMethod(_)` expects a string argument.")
            return
        }
        
        vm.setReturn(.boolean(thisClass.staticMethods[signature] != nil))
    }
    
    /// Compares two objects using built-in equality. This compares value types by value
    /// and all other objects are compared by reference: two objects are equal only if they are the exact
    /// same object.
    ///
    /// Assumes slots 0 and 1 are the values to compare.
    ///
    /// Object.<>(other) -> boolean
    private static func notEqual(vm: VM) throws {
        vm.setReturn(.boolean(!(valuesEqual(vm.getSlot(0), vm.getSlot(1)))))
    }

    /// Returns `true` if `instance` is of `type`. Walks the superclass hierarchy if necessary.
    private static func instanceIsOfType(instance: Instance, type: String) -> Bool {
        if instance.klass.name == type {
            return true
        }
        
        // Check the class hierarchy.
        var parent = instance.klass.superclass
        while parent != nil {
            if parent!.name == type {
                return true
            } else {
                parent = parent!.superclass
            }
        }
        
        return false
    }
    
    /// Returns `true` if this object's class or one of its superclasses is `other`.
    ///
    /// Assumes slots 0 and 1 are the values to compare.
    ///
    /// Object.is(other) -> boolean
    private static func is_(vm: VM) throws {
        let this = vm.getSlot(0)
        let thisType = this.type
        let other = vm.getSlot(1)
        let otherType = other.type
        
        guard let thisType = thisType, let otherType = otherType else {
            vm.setReturn(.boolean(false))
            return
        }
        
        // Same type?
        if thisType == otherType {
            vm.setReturn(.boolean(true))
            return
        }
        
        // Comparing against a string.
        if case .string(let s) = other {
            vm.setReturn(.boolean(thisType == s))
            return
        }
        
        // Both objects must be instances or classes in order for their types to match.
        switch this {
        case .instance(let thisInstance):
            guard case .instance = other else {
                vm.setReturn(.boolean(false))
                return
            }
            vm.setReturn(.boolean(instanceIsOfType(instance: thisInstance, type: otherType)))
            return
            
        case .klass(let thisClass):
            guard case .klass = other else {
                vm.setReturn(.boolean(false))
                return
            }
            vm.setReturn(.boolean(classIsOfType(klass: thisClass, type: otherType)))
            return
            
        default:
            vm.setReturn(.boolean(false))
            return
        }
    }
    
    /// Returns this object's super type as a string.
    ///
    /// Assumes:
    /// - Slot 0 is the value / instance.
    ///
    /// `Object.superType() -> string`
    private static func superType(vm: VM) throws {
        let type: String
        let value = vm.getSlot(0)
        
        switch value {
        case .boolean, .number, .string:
            type = "Object"
            
        case .instance(let instance):
            type = instance.klass.superclass?.name ?? "Object"
            
        case .klass(let klass):
            type = klass.superclass?.name ?? "Object"
            
        default:
            try vm.runtimeError(message: "`\(value.description)` has no super type.")
            return
        }
        
        vm.setReturn(.string(type))
    }
    
    /// Returns a default representation of the object as a string.
    ///
    /// Assumes:
    /// - Slot 0 is a boolean/double/string or instance.
    ///
    /// Object.toString() -> string
    private static func toString(vm: VM) throws {
        let obj = vm.getSlot(0)
        
        switch obj {
        case .instance(let instance):
            vm.setReturn(.string(instance.klass.name + " instance"))
            
        default:
            vm.setReturn(.string(obj.description))
        }
    }
    
    /// Returns this object's type as a string.
    ///
    /// Assumes:
    /// - Slot 0 is the value / instance.
    ///
    /// `Object.type() -> string`
    private static func type_(vm: VM) throws {
        guard let type = vm.getSlot(0).type else {
            try vm.runtimeError(message: "Unknown value type in slot 0.")
            return
        }
        vm.setReturn(.string(type))
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
