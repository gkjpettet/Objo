//
//  SwitchStmt.swift
//
//
//  Created by Garry Pettet on 06/11/2023.
//

import Foundation

public struct SwitchStmt: Stmt {
    /// The cases to evaluate.
    public let cases: [CaseStmt]
    /// The expression to consider.
    public let consider: Expr
    /// The optional `else` case to evaluate.
    public let elseCase: ElseCaseStmt?
    /// The location of the `switch` keyword.
    public var location: Token
    
    public init(consider: Expr, cases: [CaseStmt], elseCase: ElseCaseStmt?, keyword: Token) {
        self.consider = consider
        self.cases = cases
        self.elseCase = elseCase
        self.location = keyword
    }
    
    public func accept(_ visitor: StmtVisitor) {
        visitor.visitSwitch(stmt: self)
    }
}
