//
//  ExprVisitor.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol ExprVisitor {
    func visitAssignment(expr: AssignmentExpr)
    func visitBareInvocationExpr(expr: BareInvocationExpr)
    func visitBinary(expr: BinaryExpr)
    func visitBoolean(expr: BooleanLiteral)
    func visitField(expr: FieldExpr)
    func visitFieldAssignment(expr: FieldAssignmentExpr)
    func visitKeyValue(expr: KeyValueExpr)
    func visitLogical(expr: LogicalExpr)
    func visitMethodInvocation(expr: MethodInvocationExpr)
    func visitNothing(expr: NothingLiteral)
    func visitNumber(expr: NumberLiteral)
    func visitRange(expr: RangeExpr)
    func visitStaticField(expr: StaticFieldExpr)
    func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr)
    func visitString(expr: StringLiteral)
    func visitVariable(expr: VariableExpr)
}
