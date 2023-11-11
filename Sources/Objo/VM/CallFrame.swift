//
//  CallFrame.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//
//  Represents a single ongoing function call.

import Foundation

public struct CallFrame: Equatable {
    
    /// This call frame's function.
    public let function: Function
    
    /// The caller's instruction pointer.
    public var ip: Int
    
    /// A dictionary of the local variables currently in scope.
    /// Key = variable name, value = slot index (offset from `stackBase`) of the local variable.
    public var locals: [String : Int] = [:]
    
    /// The 0-based index in the VM's stack that this callframe considers its "base". Locals are relative to this.
    public let stackBase: Int
    
    public init(function: Function, ip: Int, stackBase: Int) {
        self.function = function
        self.ip = ip
        self.stackBase = stackBase
        self.locals = [:]
    }
}
