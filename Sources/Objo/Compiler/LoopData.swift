//
//  LoopData.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//
// Stores book-keeping information about the current loop being compiled.

import Foundation

public class LoopData {
    /// Offset of the first instruction of the body of the loop.
    public var bodyOffset: Int = 0
    
    /// The loop enclosing this one or `nil` if this is the outermost loop.
    public var enclosing: LoopData?
    
    /// Offset of the argument for the jump instruction used to exit the loop. Stored so we can patch it once we know where the loop ends.
    public var exitJump: Int = 0
    
    /// Depth of the scope(s) that need to be exited if an `exit` is hit inside the loop.
    public var scopeDepth: Int = 0
    
    /// Index of the instruction that the loop should jump back to.
    public var start: Int = 0
    
    /// The token that begins this loop.
    public var startToken: Token
    
    public init(bodyOffset: Int, enclosing: LoopData? = nil, exitJump: Int, scopeDepth: Int, start: Int, startToken: Token) {
        self.bodyOffset = bodyOffset
        self.enclosing = enclosing
        self.exitJump = exitJump
        self.scopeDepth = scopeDepth
        self.start = start
        self.startToken = startToken
    }
}
