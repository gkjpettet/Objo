//
//  StmtVisitor.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public protocol StmtVisitor {
    func visitAssertStmt(stmt: AssertStmt) throws
    func visitBlock(stmt: BlockStmt) throws
    func visitBreakpoint(stmt: BreakpointStmt) throws
    func visitCase(stmt: CaseStmt) throws
    func visitClassDeclaration(stmt: ClassDeclStmt) throws
    func visitConstructorDeclaration(stmt: ConstructorDeclStmt) throws
    func visitContinue(stmt: ContinueStmt) throws
    func visitDo(stmt: DoStmt) throws
    func visitElseCase(stmt: ElseCaseStmt) throws
    func visitExit(stmt: ExitStmt) throws
    func visitExpressionStmt(stmt: ExpressionStmt) throws
    func visitFor(stmt: ForStmt) throws
    func visitForEach(stmt: ForEachStmt) throws
    func visitForeignMethodDeclaration(stmt: ForeignMethodDeclStmt) throws
    func visitFuncDeclaration(stmt: FunctionDeclStmt) throws
    func visitIf(stmt: IfStmt) throws
    func visitMethodDeclaration(stmt: MethodDeclStmt) throws
    func visitReturn(stmt: ReturnStmt) throws
    func visitSwitch(stmt: SwitchStmt) throws
    func visitVarDeclaration(stmt: VarDeclStmt) throws
    func visitWhile(stmt: WhileStmt) throws
}
