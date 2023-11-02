//
//  ExprVisitor.swift
//
//
//  Created by Garry Pettet on 02/11/2023.
//

import Foundation

public protocol ExprVisitor {
    /// The visitor is visiting a nothing literal.
    func visitNothing(expr: NothingLiteral)
}
