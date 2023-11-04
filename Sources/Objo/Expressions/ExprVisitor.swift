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
    func visitBareSuperInvocation(expr: BareSuperInvocationExpr)
    func visitBinary(expr: BinaryExpr)
    func visitBoolean(expr: BooleanLiteral)
    func visitCall(expr: CallExpr)
    func visitClass(expr: ClassExpr)
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
    func visitPostfix(expr: PostfixExpr)
    func visitRange(expr: RangeExpr)
    func visitStaticField(expr: StaticFieldExpr)
    func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr)
    func visitString(expr: StringLiteral)
    func visitSubscript(expr: SubscriptExpr)
    func visitSubscriptSetter(expr: SubscriptSetterExpr)
    func visitSuperMethodInvocation(expr: SuperMethodInvocationExpr)
    func visitSuperSetter(expr: SuperSetterExpr)
    func visitTernary(expr: TernaryExpr)
    func visitThis(expr: ThisExpr)
    func visitUnary(expr: UnaryExpr)
    func visitVariable(expr: VariableExpr)
}
