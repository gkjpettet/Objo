//
//  CoreType.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//

import Foundation

public protocol CoreType {
    /// The user is calling the class constructor for this type.
    static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws
    
    /// Returns the method to invoke for a foreign method with `signature` on this class or `nil`
    /// if there is no such method.
    static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)?
}
