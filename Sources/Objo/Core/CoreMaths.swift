//
//  CoreMaths.swift
//
//
//  Created by Garry Pettet on 21/11/2023.
//

import Foundation

public struct CoreMaths: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    /// The value of `e`, the base of natural logarithms.
    private static let E = 2.718281828459045
    
    /// The value of `π` to 11 decimal places.
    private static let PI = 3.14159265359
    
    /// The value of τ, equivalent to 2 * π.
    private static let TAU = 6.2831853071800001
    
    /// Contains the static methods defined for the Maths class. Key = signature, value = callback.
    private static let staticMethods: [String : callback] = [
        "e()"       : e,
        "pi()"      : pi,
        "random()"  : random,
        "tau()"     : tau
    ]
    
    /// The user is calling the `Maths` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "You cannot instantiate the Maths class.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Maths` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            return staticMethods[signature]
        } else {
            // There are no instance methods on the Maths class.
            return nil
        }
    }
    
    /// Returns the value of `e`, the base of natural logarithms.
    private static func e(vm: VM) throws {
        vm.setReturn(.number(E))
    }
    
    /// Returns the value of π.
    private static func pi(vm: VM) throws {
        vm.setReturn(.number(PI))
    }
    
    /// Returns the `Random` singleton instance for this VM.
    private static func random(vm: VM) throws {
        // Ensure the VM has a single Random instance.
        if vm.randomInstance == nil {
            guard let randomInstance = vm.getVariable(name: "Random") else {
                try vm.runtimeError(message: "There is no global variable named `Random`.")
                return
            }
            guard case .klass(let randomClass) = randomInstance else {
                try vm.runtimeError(message: "There is no global class named `Random`.")
                return
            }

            vm.randomInstance = Instance(klass: randomClass)
        }
        
        vm.setReturn(.instance(vm.randomInstance!))
    }
    
    /// Returns the value of τ, equivalent to 2 * π.
    private static func tau(vm: VM) throws {
        vm.setReturn(.number(TAU))
    }
}
