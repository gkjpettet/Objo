//
//  AssertStmt.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol Expr {
    /// The token that begins this expression.
    var location: Token { get }
    
    /// Accepts a visitor.
    func accept(_ visitor: ExprVisitor)
}
