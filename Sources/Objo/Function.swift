//
//  Function.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

import Foundation

public struct Function: Method, Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(signature)
        hasher.combine(chunk.code)
        hasher.combine(chunk.constants)
        hasher.combine(parameters)
    }
    
    public static func == (lhs: Function, rhs: Function) -> Bool {
        // Same signature?
        if lhs.signature != rhs.signature { return false }
        
        // Same amount of bytecode?
        if lhs.chunk.length != rhs.chunk.length { return false }
        
        // Same number of constants?
        if lhs.chunk.constants.count() != rhs.chunk.constants.count() { return false }
        
        // Same parameter count?
        if lhs.parameters.count != rhs.parameters.count { return false }
        
        // Identical parameter names?
        for (i, param) in lhs.parameters.enumerated() {
            if param != rhs.parameters[i] { return false }
        }
        
        // We'll also check the line numbers and script IDs for a small number of the
        // bytes in the chunk as without this it is possible to get collisions
        // with very similar but distinct functions.
        if lhs.chunk.length > 0 {
            var i = 0
            let iterations = 3
            while i < lhs.chunk.length && i <= iterations {
                if lhs.chunk.lineForOffset(i) != rhs.chunk.lineForOffset(i) { return false }
                if lhs.chunk.scriptIDForOffset(i) != rhs.chunk.scriptIDForOffset(i) { return false }
                i += 1
            }
        }
        
        // If this function has any code, we'll also check three random bytes.
        if lhs.chunk.length > 0 {
            for _ in 1...3 {
                let offset = Int.random(in: 0..<lhs.chunk.length)
                if lhs.chunk.code[offset] != rhs.chunk.code[offset] { return false }
            }
        }
        
        // Looks like these two functions are equal.
        return true
    }
    
    
    // MARK: - Properties
    
    /// The number of parameters this function requires.
    public let arity: Int
    
    /// This function's chunk of bytecode.
    public var chunk: Chunk
    
    /// If `true` then this is a setter method.
    public var isSetter: Bool
    
    /// This function's name.
    public let name: String
    
    /// The names of this function's parameters (in the order they appear). May be empty.
    private(set) var parameters: [String] = []
    
    /// This function's signature.
    public let signature: String
    
    // MARK: - Public methods
    
    public init(name: String, parameters: [Token], isSetter: Bool, debugMode: Bool) throws {
        self.name = name
        self.arity = parameters.count
        
        for param in parameters {
            self.parameters.append(param.lexeme!)
        }
        
        self.isSetter = isSetter
        self.chunk = Chunk(isDebug: debugMode)
        self.signature = try Objo.computeSignature(name: self.name, arity: self.arity, isSetter: self.isSetter)
    }
    
}
