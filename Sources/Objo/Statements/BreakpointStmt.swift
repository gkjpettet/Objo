//
//  BreakpointStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct BreakpointStmt: Stmt {
    /// The `breakpoint` keyword token
    public var location: Token
    
    public init(keyword: Token) {
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) throws {
        try visitor.visitBreakpoint(stmt: self)
    }
}
