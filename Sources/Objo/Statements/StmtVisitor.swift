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
    func visitClassDeclaration(stmt: ClassDeclStmt)
    func visitConstructorDeclaration(stmt: ConstructorDeclStmt)
    func visitContinue(stmt: ContinueStmt)
    func visitExit(stmt: ExitStmt)
    func visitExpressionStmt(stmt: ExpressionStmt)
    func visitFor(stmt: ForStmt)
    func visitForEach(stmt: ForEachStmt)
    func visitForeignMethodDeclaration(stmt: ForeignMethodDeclStmt)
    func visitFuncDeclaration(stmt: FunctionDeclStmt)
    func visitIf(stmt: IfStmt)
    func visitMethodDeclaration(stmt: MethodDeclStmt)
    func visitReturn(stmt: ReturnStmt)
    func visitVarDeclaration(stmt: VarDeclStmt)
    func visitWhile(stmt: WhileStmt)
}
