//
//  Opcode.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Opcode: UInt8 {
    case add
    case bitwiseAnd
    case bitwiseOr
    case bitwiseXor
    case class_
    case constant
    case constantLong
    case constructor
    case defineGlobal
    case defineGlobalLong
    case divide
    case equal
    case false_
    case getField
    case getGlobal
    case getGlobalLong
    case getLocal
    case getStaticField
    case getStaticFieldLong
    case greater
    case greaterEqual
    case greaterGreater
    case less
    case lessEqual
    case lessLess
    case modulo
    case multiply
    case notEqual
    case nothing
    case pop
    case return_
    case setGlobal
    case setGlobalLong
    case setField
    case setStaticField
    case setStaticFieldLong
    case shiftLeft
    case shiftRight
    case subtract
    case true_
}
