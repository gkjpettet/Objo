//
//  StmtVisitor.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public protocol StmtVisitor {
    func visitAssertStmt(stmt: AssertStmt)
    func visitBlock(stmt: BlockStmt)
    func visitExpressionStmt(stmt: ExpressionStmt)
    func visitFuncDeclaration(stmt: FunctionDeclStmt)
    func visitVarDeclaration(stmt: VarDeclStmt)
}
