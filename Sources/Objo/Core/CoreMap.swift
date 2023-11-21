//
//  CoreMap.swift
//
//
//  Created by Garry Pettet on 21/11/2023.
//

import Foundation

public struct CoreMap: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    // MARK: - Private static properties
    
    /// Contains the instance methods defined for the Map class. Key = signature, value = callback.
    private static let instanceMethods: [String : callback] = [
        "clear()"           : clear,
        "containsKey(_)"    : containsKey,
        "count()"           : count,
        "iterate(_)"        : iterate,
        "iteratorValue(_)"  : iteratorValue,
        "keys()"            : keys,
        "remove(_)"         : remove,
        "toString()"        : toString,
        "values()"          : values,
        "[_]=(_)"           : subscriptSetter,
        "[_]"               : subscript_
    ]
        
    /// MARK: - Public static methods
    
    /// The user is calling the `Map` class constructor.
    ///
    /// `constructor()`
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        if arguments.count == 0 {
            instance.foreignData = MapData()
        } else {
            try vm.runtimeError(message: "Invalid number of arguments (expected 0, got \(arguments.count)).")
        }
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Map` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            // There are no static methods on the Map class.
            return nil
        } else {
            return instanceMethods[signature]
        }
    }
    
    // MARK: - Private static methods
    
    /// Removes all entries from the map.
    ///
    /// `Map.clear() -> nothing`
    private static func clear(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard instance.foreignData is MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        instance.foreignData = MapData()
    }
    
    /// Returns true if the map contains `key` or false if it doesn't.
    ///
    /// `Map.containsKey(key) -> boolean`
    private static func containsKey(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        vm.setReturn(.boolean(data.data[vm.getSlot(1)] != nil))
    }
    
    /// Returns the number of keys in the map.
    ///
    /// `Map.count() -> count`
    private static func count(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        vm.setReturn(.number(Double(data.data.count)))
    }
    
    /// Returns false if there are no more items to iterate or returns the index in the
    /// dictionary's keys array of the next value in the map.
    ///
    /// if `iter` is nothing then we should return the first index.
    ///
    /// `Map.iterate(iter) -> value or false`
    private static func iterate(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        let keys = Array(data.data.keys)
        
        switch vm.getSlot(1) {
        case .instance(let instance):
            if instance.klass.name == "Nothing" {
                // Return the index of the first key or false if the map is empty.
                if keys.count == 0 {
                    vm.setReturn(.boolean(false))
                    return
                } else {
                    vm.setReturn(.number(0))
                    return
                }
            } else {
                try vm.runtimeError(message: "The iterator must be either `Nothing` or an integer.")
                return
            }
            
        case .number(let iterNumber):
            guard let index = Int(exactly: iterNumber) else {
                try vm.runtimeError(message: "The iterator must be an integer.")
                return
            }
            
            // Return the next index unless we've reached the end of the keys array when we return false.
            if index < 0 || index >= keys.count - 1 {
                vm.setReturn(.boolean(false))
                return
            } else {
                vm.setReturn(.number(Double(index + 1)))
                return
            }
            
        default:
            try vm.runtimeError(message: "The iterator must be either `Nothing` or an integer.")
            return
        }
    }
    
    /// Returns the next iterator value.
    ///
    /// Uses `iter` to determine the next value in the iteration. It should be an index in the dictionary's keys array.
    
    /// `Map.iteratorValue(iter) -> value`
    public static func iteratorValue(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        let keys = Array(data.data.keys)
        
        guard case .number(let iter) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The iterator must be an integer.")
            return
        }
        
        guard let index = Int(exactly: iter) else {
            try vm.runtimeError(message: "The iterator must be an integer.")
            return
        }
        
        if index < 0 || index >= keys.count {
            try vm.runtimeError(message: "The iterator is out of bounds.")
            return
        }
        
        // Create a new KeyValue instance.
        let kv = Instance(klass: vm.keyValueClass!)
        kv.foreignData = KeyValueData(key: .number(Double(index)), value: data.data[keys[index]]!)
        
        // Return the KeyValue instance.
        vm.setReturn(.instance(kv))
    }
    
    /// Returns a list containing this map's keys. The order of the keys is undefined but it is
    /// guaranteed that all keys will be returned.
    ///
    /// `Map.keys() -> List`
    private static func keys(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        vm.setReturn(.instance(vm.newList(items: Array(data.data.keys))))
    }
    
    /// Removes `key` and the value associated with it from the map. Returns the value.
    /// If `key` was not present, returns nothing.
    ///
    /// `Map.remove(key) -> value or nothing`
    private static func remove(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        if let value = data.data[vm.getSlot(1)] {
            data.data.removeValue(forKey: value)
            vm.setReturn(value)
            return
        } else {
            // Implictly return nothing.
            return
        }
    }
    
    /// Returns the value for the specified key or nothing if the key doesn't exist.
    ///
    /// `Map.[key]`
    private static func subscript_(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        let key = vm.getSlot(1)
        
        let value = data.data[key] ?? .instance(vm.nothing!)
        
        vm.setReturn(value)
    }
    
    /// Assigns a value to a specified key.
    ///
    /// `Map.[key]=(value)`
    private static func subscriptSetter(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        let key = vm.getSlot(1)
        
        let value = vm.getSlot(2)
        
        data.data[key] = value
    }
    
    /// Returns a string representation of this map.
    ///
    /// Assumes:
    /// `Map.toString -> String`
    private static func toString(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        var s: [String] = []
        for (key, value) in data.data {
            s.append(key.description + " : " + value.description)
        }
        
        let result = "{" + s.joined(separator: ", ") + "}"
        vm.setReturn(.string(result))
    }
    
    /// Returns a list containing this map's values. The order of the values is undefined but it is
    /// guaranteed that all values will be returned.
    ///
    /// `Map.values() -> List`
    private static func values(vm: VM) throws {
        guard case .instance(let instance) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a Map instance in slot 0.")
            return
        }
        
        guard let data = instance.foreignData as? MapData else {
            try vm.runtimeError(message: "Expected the foreign data of the instance in slot 0 to be `MapData`.")
            return
        }
        
        vm.setReturn(.instance(vm.newList(items: Array(data.data.values))))
    }
}
