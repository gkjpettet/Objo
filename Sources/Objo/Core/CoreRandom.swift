//
//  CoreRandom.swift
//
//
//  Created by Garry Pettet on 21/11/2023.
//

import Foundation

public struct CoreRandom: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    /// Contains the instance methods defined for the Random class. Key = signature, value = callback.
    private static let instanceMethods: [String : callback] = [
        "inRange(_,_)"  : inRange,
        "lessThan(_)"   : lessThan,
        "number()"      : number
    ]
    
    // MARK: - Public static methods
    
    /// The user is calling the `Random` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "The Random class does not have a constructor.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `Random` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if isStatic {
            // There are no static methods on the Random class.
            return nil
        }
        
        return instanceMethods[signature]
    }
    
    // MARK: - Private static methods
    
    /// Returns a random integer in the range `min` to `max` inclusive.
    ///
    /// `Random.inRange(min, max) -> integer Number`
    private static func inRange(vm: VM) throws {
        guard case .number(let min) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `min` argument must be an integer.")
            return
        }
        
        guard let min = Int(exactly: min) else {
            try vm.runtimeError(message: "The `min` argument must be an integer.")
            return
        }
        
        guard case .number(let max) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `max` argument must be an integer.")
            return
        }
        
        guard let max = Int(exactly: max) else {
            try vm.runtimeError(message: "The `max` argument must be an integer.")
            return
        }
        
        vm.setReturn(.number(Double(Int.random(in: min...max))))
    }
    
    /// Returns a random integer (`result`) where: `0 <= result < upper`.
    ///
    /// `Random.lessThan(upper) -> integer Number`
    private static func lessThan(vm: VM) throws {
        guard case .number(let upper) = vm.getSlot(1) else {
            try vm.runtimeError(message: "The `upper` argument must be a positive integer.")
            return
        }
        
        guard let upper = Int(exactly: upper) else {
            try vm.runtimeError(message: "The `upper` argument must be a positive integer.")
            return
        }
        
        guard upper >= 0 else {
            try vm.runtimeError(message: "The `upper` argument must be a positive integer.")
            return
        }
        
        vm.setReturn(.number(Double(Int.random(in: 0...upper))))
    }
    
    /// Returns a random double in the range: `0 <= result <= 1.0`.
    ///
    /// `Random.number() -> number.`
    private static func number(vm: VM) throws {
        vm.setReturn(.number(Double.random(in: 0..<1)))
    }
}
