//
//  CoreSystem.swift
//
//
//  Created by Garry Pettet on 21/11/2023.
//

import Foundation

public struct CoreSystem: CoreType {
    
    typealias callback = (VM) throws -> Void
    
    // MARK: - Private static properties
    
    /// Contains the static methods defined for the System class. Key = signature, value = callback.
    private static let staticMethods: [String : callback] = [
        "clock()"   : clock,
        "print(_)"  : print_
    ]
    
    // MARK: - Public static methods
    
    /// The user is calling the `System` class constructor.
    public static func allocate(vm: VM, instance: Instance, arguments: [Value]) throws {
        try vm.runtimeError(message: "You cannot instantiate the System class.")
    }
    
    /// Returns the method to invoke for a foreign method with `signature` on the `System` class or `nil`
    /// if there is no such method.
    public static func bindForeignMethod(signature: String, isStatic: Bool) -> ((VM) throws -> Void)? {
        if !isStatic {
            // All methods on `System` are static.
            return nil
        }
        
        return staticMethods[signature]
    }
    
    // MARK: - Private static methods
    
    /// Returns the date since the system booted.
    ///
    /// Credit: https://stackoverflow.com/a/57170110/278816
    private static func bootTime() -> Date? {
        var tv = timeval()
        var tvSize = MemoryLayout<timeval>.size
        let err = sysctlbyname("kern.boottime", &tv, &tvSize, nil, 0);
        guard err == 0, tvSize == MemoryLayout<timeval>.size else {
            return nil
        }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000.0)
    }
    
    /// Returns the number of microseconds since the host application started.
    ///
    /// `System.clock() -> double`
    private static func clock(vm: VM) throws {
        guard let bootDate = bootTime() else {
            vm.setReturn(.number(0))
            return
        }
        
        let now = Date()
        let microseconds = Int((now.timeIntervalSince1970 - bootDate.timeIntervalSince1970) * 1000000)
        vm.setReturn(.number(Double(microseconds)))
    }
    
    /// Computes a string representation of the passed argument and calls the VM's
    /// `print` callback. Returns the value printed.
    ///
    /// `System.print(what) -> what`
    private static func print_(vm: VM) throws {
        let value = vm.getSlot(1)
        
        vm.print?(value.description)
        
        vm.setReturn(value)
    }
}
