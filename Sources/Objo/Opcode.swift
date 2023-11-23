//
//  Opcode.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Opcode: UInt8 {
    case add                    = 0
    case add1                   = 1
    case assert                 = 2
    case bitwiseAnd             = 3
    case bitwiseNot             = 4
    case bitwiseOr              = 5
    case bitwiseXor             = 6
    case breakpoint             = 7
    case call                   = 8
    case class_                 = 9
    case constant               = 10
    case constantLong           = 11
    case constructor            = 12
    case debugFieldName         = 13
    case defineGlobal           = 14
    case defineGlobalLong       = 15
    case defineNothing          = 16
    case divide                 = 17
    case equal                  = 18
    case exit                   = 19
    case false_                 = 20
    case foreignMethod          = 21
    case getField               = 22
    case getGlobal              = 23
    case getGlobalLong          = 24
    case getLocal               = 25
    case getLocalClass          = 26
    case getStaticField         = 27
    case getStaticFieldLong     = 28
    case greater                = 29
    case greaterEqual           = 30
    case inherit                = 31
    case invoke                 = 32
    case invokeLong             = 33
    case is_                    = 34
    case jump                   = 35
    case jumpIfFalse            = 36
    case jumpIfTrue             = 37
    case keyValue               = 38
    case less                   = 39
    case lessEqual              = 40
    case list                   = 41
    case load0                  = 42
    case load1                  = 43
    case load2                  = 44
    case loadMinus1             = 45
    case loadMinus2             = 46
    case localVarDeclaration    = 47
    case logicalXor             = 48
    case loop                   = 49
    case map                    = 50
    case method                 = 51
    case modulo                 = 52
    case multiply               = 53
    case negate                 = 54
    case not                    = 55
    case notEqual               = 56
    case nothing                = 57
    case pop                    = 58
    case popN                   = 59
    case rangeExclusive         = 60
    case rangeInclusive         = 61
    case return_                = 62
    case setGlobal              = 63
    case setGlobalLong          = 64
    case setField               = 65
    case setLocal               = 66
    case setStaticField         = 67
    case setStaticFieldLong     = 68
    case shiftLeft              = 69
    case shiftRight             = 70
    case subtract               = 71
    case subtract1              = 72
    case superConstructor       = 73
    case superInvoke            = 74
    case superSetter            = 75
    case swap                   = 76
    case true_                  = 77
}
