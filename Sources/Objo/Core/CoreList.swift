//
//  CoreList.swift
//
//
//  Created by Garry Pettet on 20/11/2023.
//

import Foundation

public struct CoreList: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    // MARK: - Private static properties
    
    /// Contains the instance methods defined for the List class. Key = signature, value = callback.
    private static let instanceMethods: [String : callback] = [
        "add(_)"            : add,
        "clear()"           : clear,
        "clone()"           : clone,
        "count()"           : count,
        "indexOf(_)"        : indexOf,
        "insert(_,_)"       : insert,
        "iterate(_)"        : iterate,
        "iteratorValue(_)"  : iteratorValue,
        "pop()"             : pop,
        "remove(_)"         : remove,
        "removeAt(_)"       : removeAt,
        "swap(_,_)"         : swap,
        "toString()"        : toString,
        "[_]=(_)"           : subscriptSetter,
        "[_]"               : subscript_
    ]
    
    /// Contains the static methods defined for the List class. Key = signature, value = callback.
    private static let staticMethods: [String : callback] = [
        "filled(_,_)"   : filled
    ]
    
    // MARK: - Public methods
    
    /// The user is calling the `List` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        guard arguments.count == 0 else {
            try vm.runtimeError(message: "Invalid number of arguments (got \(arguments.count), expected 0).")
            return
        }
        
        instance.foreignData = ListData()
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `List` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            return staticMethods[signature]
        } else {
            return instanceMethods[signature]
        }
    }
    
    // MARK: - Private static methods
    
    /// Appends an item to the end of the list. Returns the added item.
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    /// - Slot 1 is the item to append.
    ///
    /// `List.add(item) -> item`
    private static func add(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        (list.foreignData as! ListData).items.append(vm.getSlot(1))
    }
    
    /// Removes all elements from the list.
    ///
    /// Assumes slot 0 contains a List instance.
    ///
    /// `List.clear() -> nothing`
    private static func clear(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        (list.foreignData as! ListData).items.removeAll()
    }
    
    /// Returns a shallow clone of this list.
    ///
    /// Assumes slot 0 contains a List instance.
    ///
    /// `List.clone() -> List`
    private static func clone(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        vm.setReturn(.instance(cloneList(list: list, vm: vm)))
    }
    
    /// Returns a shallow clone of `list`.
    /// Assumes `list` is a List instance.
    private static func cloneList(list: Instance, vm: VM) -> Instance {
        let data: ListData = list.foreignData as! ListData
        
        var clonedItems: [Value] = []
        for item in data.items {
            clonedItems.append(item)
        }
        
        return vm.newList(items: clonedItems)
    }
    
    /// Returns the number of items in the list.
    ///
    /// Assumes slot 0 contains a List instance.
    ///
    /// `List.count() -> count`
    private static func count(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        vm.setReturn(.number(Double((list.foreignData as! ListData).count)))
    }
    
    /// Creates a new list with `size` elements, all set to `element`.
    ///
    /// Setup:
    /// - Slot 0 is the List class.
    /// - Slot 1 should be a non-negative integer (runtime error otherwise).
    /// - Slot 2 is the element to replicate.
    ///
    /// `List.filled(size, element) -> List instance`
    private static func filled(vm: VM) throws {
        guard case .number(let size) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`size` must be an integer.")
            return
        }
        
        guard let size = Int(exactly: size) else {
            try vm.runtimeError(message: "`size` must be an integer.")
            return
        }
        
        guard size >= 0 else {
            try vm.runtimeError(message: "`size` cannot be negative.")
            return
        }
        
        let element = vm.getSlot(2)
        let items: [Value] = Array(repeating: element, count: size)
        
        vm.setReturn(.instance(vm.newList(items: items)))
    }
    
    /// Returns the index of `value` in the list, if found. If not found it returns `-1`.
    ///
    /// Assumes:
    /// - Slot 0 is a List instance.
    /// - Slot 1 is the value.
    ///
    /// `List.indexOf(value) -> number`
    private static func indexOf(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        vm.setReturn(.number(Double(data.items.firstIndex(of: vm.getSlot(1)) ?? -1)))
    }
    
    /// Inserts `item` at `index` in the list and returns the inserted item.
    ///
    /// Assumes:
    /// - Slot 0 is a List instance.
    /// - Slot 1 is the index to insert at.
    /// - Slot 2 is the item to insert.
    ///
    /// `List.insert(index, item) -> item`
    ///
    /// The index may be one past the last index in the list to append an element.
    /// If `index` is < 0 it counts backwards from the end of the list. It bases the
    /// computation on the length of the list _after_ the inserted the element, so
    /// that -1 will append the element, not insert it before the last element.
    ///
    /// If `index` is not an integer or is out of bounds, a runtime error occurs.
    private static func insert(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        // Get `index` and assert it's an integer.
        guard case .number(let index) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`index` must be an integer.")
            return
        }
        
        guard var index = Int(exactly: index) else {
            try vm.runtimeError(message: "`index` must be an integer.")
            return
        }
        
        let value = vm.getSlot(2)
        
        // Append?
        if index == data.lastIndex + 1 {
            data.items.append(value)
            vm.setReturn(value)
            return
        }
        
        // Assert `index` is within bounds and recompute if necessary.
        if index > data.lastIndex + 1 {
            try vm.runtimeError(message: "`index` is out of bounds.")
            return
        } else if index < 0 {
            if abs(index) > data.count + 1 {
                try vm.runtimeError(message: "`index` is out of bounds.")
                return
            } else {
                index = data.count + index + 1
            }
        }
        
        data.items.insert(value, at: index)
        
        vm.setReturn(value)
    }
    
    /// Returns false if there are no more items to iterate or returns the index in the array
    /// of the next value in the list.
    ///
    /// if `iter` is nothing then we should return the first index.
    /// Assumes slot 0 contains a List instance.
    ///
    /// `List.iterate(iter) -> value or false`
    private static func iterate(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        let iter = vm.getSlot(1)
        
        switch iter {
        case .instance(let iterInstance):
            if iterInstance.klass.name == "Nothing" {
                // Return the index of the first item or false if the list is empty.
                if data.count == 0 {
                    vm.setReturn(.boolean(false))
                    return
                } else {
                    vm.setReturn(.number(0))
                    return
                }
            }
            
        case .number(let iterNumber):
            guard let iterInt = Int(exactly: iterNumber) else {
                try vm.runtimeError(message: "The iterator must be an integer.")
                return
            }
            
            // Return the next index unless we've reached the end of the array when we return false.
            if iterInt < 0 || iterInt >= data.lastIndex {
                vm.setReturn(.boolean(false))
                return
            } else {
                vm.setReturn(.number(Double(iterInt + 1)))
                return
            }
            
        default:
            try vm.runtimeError(message: "The iterator must be an integer.")
            return
        }
    }
    
    /// Returns the next iterator value.
    ///
    /// Assumes:
    /// - Slot 0 is a List instance.
    /// - Slot 1 is an integer.
    ///
    /// Uses `iter` to determine the next value in the iteration. It should be an index in the array.
    ///
    /// `List.iteratorValue(iter) -> value`
    private static func iteratorValue(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        guard case .number(let iter) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The iteratorm must be an integer.")
            return
        }
        
        guard let index = Int(exactly: iter) else {
            try vm.runtimeError(message: "The iteratorm must be an integer.")
            return
        }
        
        if index < 0 || index  > data.lastIndex {
            try vm.runtimeError(message: "The iterator is out of bounds.")
            return
        }
        
        vm.setReturn(data.items[index])
    }
    
    /// Pops the highest index item off the list and returns it.
    /// It's a runtime error if the list is empty.
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    ///
    /// `List.pop() -> item`
    private static func pop(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        if data.count == 0 {
            try vm.runtimeError(message: "Cannot pop an empty list.")
            return
        } else {
            vm.setReturn(data.items.popLast()!)
        }
    }
    
    /// Removes the first value found that matches the given `value`.
    /// Trailing elements are shifted up to fill in where the removed element was.
    /// Returns the removed value if found or nothing if not found.
    ///
    /// Assumes:
    /// - Slot 0 is a List instance.
    /// - Slot 1 is the value.
    ///
    /// `List.remove(value) -> value or nothing`
    private static func remove(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        let value = vm.getSlot(1)
        
        let index = data.items.firstIndex(of: value) ?? -1
        
        if index != -1 {
            data.items.remove(at: index)
            vm.setReturn(value)
        }
    }
    
    /// Removes the element at `index`.
    /// Returns the removed value.
    ///
    /// If `index` is negative it counts backwards from the end of the list where `-1` is the last element.
    /// Elements are shifted up to fill in where the removed element was.
    /// It is a runtime error if `index` is not an integer or is out of bounds.
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    /// - Slot 1 is the index.
    ///
    /// `List.removeAt(index) -> item`
    private static func removeAt(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        // Get `index` and assert it's an integer.
        guard case .number(let index) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`index` must be an integer.")
            return
        }
        
        guard var index = Int(exactly: index) else {
            try vm.runtimeError(message: "`index` must be an integer.")
            return
        }
        
        // Adjust `index`, accounting for backwards counting.
        index = index >= 0 ? index : data.count + index
        
        if index > data.lastIndex || index < 0 {
            try vm.runtimeError(message: "List index is out of bounds.")
            return
        }
        
        // Remove the item.
        let item = data.items[index]
        data.items.remove(at: index)
        
        // Return the removed item.
        vm.setReturn(item)
    }
    
    /// Swaps values inside the list around. Puts the value from `index0` in `index1`
    /// and the value from `index1` at `index0` in the list.
    ///
    /// Assumes:
    /// - Slot 0 is a List instance.
    /// - Slot 1 is `index0`
    /// - Slot 2 is `index1`
    ///
    ///
    /// `List.swap(index0, index1) -> nothing`
    private static func swap(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        // Get the indexes and assert they are both integers.
        guard case .number(let index0) = vm.getSlot(1) else {
            try vm.runtimeError(message: "`index0` must be an integer.")
            return
        }
        
        guard let index0 = Int(exactly: index0) else {
            try vm.runtimeError(message: "`index0` must be an integer.")
            return
        }
        
        guard case .number(let index1) = vm.getSlot(2) else {
            try vm.runtimeError(message: "`index1` must be an integer.")
            return
        }
        
        guard let index1 = Int(exactly: index1) else {
            try vm.runtimeError(message: "`index1` must be an integer.")
            return
        }
        
        // Bounds check.
        if index0 < 0 || index0 > data.lastIndex {
            try vm.runtimeError(message: "`index0` is out of bounds.")
            return
        }
        if index1 < 0 || index1 > data.lastIndex {
            try vm.runtimeError(message: "`index1` is out of bounds.")
            return
        }
        
        // Swap.
        let tmp = data.items[index0]
        data.items[index0] = data.items[index1]
        data.items[index1] = tmp
    }
    
    /// Returns a string representation of this array in the format: "[item1, itemN]".
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    ///
    /// `List.toString -> String`
    private static func toString(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        var s: [String] = []
        for item in data.items {
            s.append(item.description)
        }
        
        let result = "[" + s.joined(separator: ", ") + "]"
        
        vm.setReturn(.string(result))
    }
    
    /// Returns the value at the specified index.
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    /// - Slot 1 is the index (needs to be an integer double or a positive range).
    ///
    /// `List.[index]`

    private static func subscript_(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        // The index can be an integer or a positive range.
        switch vm.getSlot(1) {
        case .number(let index):
            guard var index = Int(exactly: index) else {
                try vm.runtimeError(message: "Subscript index must be an integer or a range.")
                return
            }
            
            // E.g: list[3].
            
            // Adjust `index`, accounting for backwards counting.
            index = index >= 0 ? index : data.count + index
            
            if index < 0 || index > data.lastIndex {
                try vm.runtimeError(message: "List index is out of bounds.")
                return
            }
            
            vm.setReturn(data.items[index])
            return
            
        case .instance(let range):
            guard range.klass.name == "List" else {
                try vm.runtimeError(message: "Subscript index must be an integer or a range.")
                return
            }
            
            // E.g: list[1...2].
            
            var newListItems: [Value] = []
            for value in (range.foreignData as! ListData).items {
                guard case .number(let v) = value else {
                    try vm.runtimeError(message: "Expected range index to be a positive integer, instead got \(value).")
                    return
                }
                
                guard let rangeIndex = Int(exactly: v) else {
                    try vm.runtimeError(message: "Expected range index to be a positive integer, instead got \(v).")
                    return
                }
                
                if rangeIndex < 0 || rangeIndex > data.lastIndex {
                    try vm.runtimeError(message: "Range index iis out of bounds (\(rangeIndex).")
                    return
                }
                newListItems.append(data.items[rangeIndex])
            }
         
            vm.setReturn(.instance(vm.newList(items: newListItems)))
            return
            
        default:
            try vm.runtimeError(message: "Subscript index must be an integer or a range.")
            return
        }
    }
    
    /// Assigns a value to a specified index.
    ///
    /// Assumes:
    /// - Slot 0 contains a List instance.
    /// - Slot 1 is the index (needs to be an integer double).
    /// - Slot 2 is the value to assign.
    ///
    /// `List.[index]=(value)`
    private static func subscriptSetter(vm: VM) throws {
        guard case .instance(let list) = vm.getSlot(0) else {
            try vm.runtimeError(message: "Expected a List instance in slot 0.")
            return
        }
        
        let data: ListData = list.foreignData as! ListData
        
        guard case .number(let index) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The subscript index must be an integer.")
            return
        }
        
        guard var index = Int(exactly: index) else {
            try vm.runtimeError(message: "The subscript index must be an integer.")
            return
        }
        
        // Adjust `index`, accounting for backwards counting.
        index = index >= 0 ? index : data.count + index
        
        if index < 0 || index > data.lastIndex {
            try vm.runtimeError(message: "The subscript index is out of bounds (\(index).")
            return
        }
        
        data.items[index] = vm.getSlot(2)
    }
    
    
}
