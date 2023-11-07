//
//  Function.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//

import Foundation

public struct Function {
    
    /// The number of parameters this function requires.
    public let arity: Int
    /// This function's chunk of bytecode.
    public var chunk: Chunk
    /// If `true` then this is a setter method.
    public let isSetter: Bool
    /// This function's name.
    public let name: String
    /// The names of this function's parameters (in the order they appear). May be empty.
    public let parameters: [String]
    /// This function's signature.
    public let signature: String
    
    public init(name: String, parameters: [Token], isSetter: Bool, debugMode: Bool) {
        self.name = name
        self.arity = parameters.count
        
        for param in parameters {
            self.parameters.append(param.lexeme!)
        }
        
        self.isSetter = isSetter
        
        self.chunk = Chunk(debugMode: debugMode)
        
        self.signature = Objo.computeSignature(name: self.name, arity: self.arity, isSetter: self.isSetter)
    }
    
}
