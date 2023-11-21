//
//  KeyValueData.swift
//
//
//  Created by Garry Pettet on 20/11/2023.
//

import Foundation

public class KeyValueData {
    /// The key.
    public var key: Value
    
    /// The value.
    public var value: Value
    
    public init(key: Value, value: Value) {
        self.key = key
        self.value = value
    }
}
