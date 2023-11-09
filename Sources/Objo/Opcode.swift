//
//  Opcode.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Opcode: UInt8 {
    case add
    case add1
    case assert
    case bitwiseAnd
    case bitwiseOr
    case bitwiseXor
    case breakpoint
    case call
    case class_
    case constant
    case constantLong
    case constructor
    case debugFieldName
    case defineGlobal
    case defineGlobalLong
    case defineNothing
    case divide
    case equal
    case exit
    case false_
    case foreignMethod
    case getField
    case getGlobal
    case getGlobalLong
    case getLocal
    case getLocalClass
    case getStaticField
    case getStaticFieldLong
    case greater
    case greaterEqual
    case greaterGreater
    case inherit
    case invoke
    case invokeLong
    case is_
    case jump
    case jumpIfFalse
    case jumpIfTrue
    case keyValue
    case less
    case lessEqual
    case lessLess
    case list
    case load0
    case load1
    case load2
    case loadMinus1
    case loadMinus2
    case localVarDeclaration
    case logicalXor
    case loop
    case map
    case method
    case modulo
    case multiply
    case negate
    case not
    case notEqual
    case nothing
    case pop
    case popN
    case rangeExclusive
    case rangeInclusive
    case return_
    case setGlobal
    case setGlobalLong
    case setField
    case setLocal
    case setStaticField
    case setStaticFieldLong
    case shiftLeft
    case shiftRight
    case subtract
    case subtract1
    case superConstructor
    case superInvoke
    case superSetter
    case swap
    case true_
}
