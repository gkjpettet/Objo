//
//  ExprVisitor.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol ExprVisitor {
    func visitAssignment(expr: AssignmentExpr) throws
    func visitBareInvocation(expr: BareInvocationExpr) throws
    func visitBareSuperInvocation(expr: BareSuperInvocationExpr) throws
    func visitBinary(expr: BinaryExpr) throws
    func visitBoolean(expr: BooleanLiteral) throws
    func visitCall(expr: CallExpr) throws
    func visitClass(expr: ClassExpr) throws
    func visitField(expr: FieldExpr) throws
    func visitFieldAssignment(expr: FieldAssignmentExpr) throws
    func visitKeyValue(expr: KeyValueExpr) throws
    func visitListLiteral(expr: ListLiteral) throws
    func visitLogical(expr: LogicalExpr) throws
    func visitMethodInvocation(expr: MethodInvocationExpr) throws
    func visitIs(expr: IsExpr) throws
    func visitMapLiteral(expr: MapLiteral) throws
    func visitNothing(expr: NothingLiteral) throws
    func visitNumber(expr: NumberLiteral) throws
    func visitPostfix(expr: PostfixExpr) throws
    func visitRange(expr: RangeExpr) throws
    func visitStaticField(expr: StaticFieldExpr) throws
    func visitStaticFieldAssignment(expr: StaticFieldAssignmentExpr) throws
    func visitString(expr: StringLiteral) throws
    func visitSubscript(expr: SubscriptExpr) throws
    func visitSubscriptSetter(expr: SubscriptSetterExpr) throws
    func visitSuperMethodInvocation(expr: SuperMethodInvocationExpr) throws
    func visitSuperSetter(expr: SuperSetterExpr) throws
    func visitTernary(expr: TernaryExpr) throws
    func visitThis(expr: ThisExpr) throws
    func visitUnary(expr: UnaryExpr) throws
    func visitVariable(expr: VariableExpr) throws
}
