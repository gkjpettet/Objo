//
//  Stmt.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public protocol Stmt {
    /// The token that begins this statement.
    var location: Token { get }
    
    /// Accepts a visitor.
    func accept(_ visitor: StmtVisitor)
}
