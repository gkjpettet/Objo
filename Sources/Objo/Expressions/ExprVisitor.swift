//
//  ExprVisitor.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol ExprVisitor {
    func visitBinary(expr: BinaryExpr)
    func visitBoolean(expr: BooleanLiteral)
    func visitKeyValue(expr: KeyValueExpr)
    func visitLogical(expr: LogicalExpr)
    func visitMethodInvocation(expr: MethodInvocationExpr)
    func visitNothing(expr: NothingLiteral)
    func visitNumber(expr: NumberLiteral)
    func visitRange(expr: RangeExpr)
    func visitString(expr: StringLiteral)
}
