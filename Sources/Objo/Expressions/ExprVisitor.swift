//
//  ExprVisitor.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol ExprVisitor {
    func visitAssignment(expr: AssignmentExpr)
    func visitBareInvocation(expr: BareInvocationExpr)
    func visitBinary(expr: BinaryExpr)
    func visitBoolean(expr: BooleanLiteral)
    func visitCall(expr: CallExpr)
    func visitField(expr: FieldExpr)
    func visitFieldAssignment(expr: FieldAssignmentExpr)
    func visitKeyValue(expr: KeyValueExpr)
    func visitListLiteral(expr: ListLiteral)
    func visitLogical(expr: LogicalExpr)
    func visitMethodInvocation(expr: MethodInvocationExpr)
    func visitIs(expr: IsExpr)
    func visitMapLiteral(expr: MapLiteral)
    func visitNothing(expr: NothingLiteral)
    func visitNumber(expr: NumberLiteral)
    func visitRange(expr: RangeExpr)
    func visitStaticField(expr: StaticFieldExpr)
    func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr)
    func visitString(expr: StringLiteral)
    func visitSubscript(expr: SubscriptExpr)
    func visitSubscriptSetter(expr: SubscriptSetterExpr)
    func visitTernary(expr: TernaryExpr)
    func visitUnary(expr: UnaryExpr)
    func visitVariable(expr: VariableExpr)
}
