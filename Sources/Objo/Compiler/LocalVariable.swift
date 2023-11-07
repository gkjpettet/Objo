//
//  LocalVariable.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//
//  Represents a local variable in the compiler.

import Foundation

public struct LocalVariable {
    
    /// The scope depth of the block this variable was declared within.
    /// `-1` indicates the variable has not yet been initialised.
    public let depth: Int
    
    /// The token in the source code representing this local variable's name (its identifier).
    public let identifier: Token
    
    /// This local variable's name.
    public var name: String { return identifier.lexeme! }
   
    public init(identifier: Token, depth: Int = -1) {
        self.identifier = identifier
        self.depth = depth
    }
    
}
