//
//  ConstantTable.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//
// A data structure for storing VM constants (objects that conform to the `Value` protocol).
// We can't use Swift's native `Set` because we need to ensure that the index of an added element
// is constant.

import Foundation

public struct ConstantTable {
    
    private var items: [Value] = []
    
    /// Adds a value to this contant table and returns its index. If the value already exists in the table then
    /// just its index is returned.
    mutating public func add(_ value: Value) -> Int {
        if let index = items.firstIndex(of: value) {
            // This value already exists.
            return index
        } else {
            // Add this value and then return its index.
            items.append(value)
            return items.count - 1
        }
    }
    
    /// Returns the value at the specified index (if it exists).
    public subscript(index: Int) -> Value? {
        return items[safelyIndex: index]
    }
}
