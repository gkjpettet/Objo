//
//  StmtVisitor.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public protocol StmtVisitor {
    /// The visitor is visiting an `assert` statement.
    func visitAssertStmt(stmt: AssertStmt)
    
    /// The visitor is visiting an expression statement.
    func visitExpressionStmt(stmt: ExpressionStmt)
    
    /// The visitor is visiting a variable declaration.
    func visitVarDeclaration(stmt: VarDeclStmt)
}
