//
//  TokenType.swift
//  
//
//  Created by Garry Pettet on 24/10/2023.
//

import Foundation

public enum TokenType: Equatable, Hashable {
    case and
    case ampersand
    case as_
    case assert
    case boolean
    case breakpoint
    case caret
    case case_
    case class_
    case colon
    case comma
    case continue_
    case constructor
    case do_
    case dot
    case dotDotDot
    case dotDotLess
    case else_
    case eof
    case endOfLine
    case equal
    case equalEqual
    case exit
    case export
    case fieldIdentifier
    case for_
    case foreach
    case foreign
    case forwardSlash
    case forwardSlashEqual
    case function
    case greater
    case greaterEqual
    case greaterGreater
    case identifier
    case if_
    case import_
    case in_
    case is_
    case lcurly
    case less
    case lessEqual
    case lessLess
    case loop
    case lparen
    case lsquare
    case minus
    case minusEqual
    case minusMinus
    case not
    case notEqual
    case nothing
    case number
    case or
    case percent
    case plus
    case plusEqual
    case plusPlus
    case pipe
    case query
    case rcurly
    case return_
    case rparen
    case rsquare
    case semicolon
    case select
    case self_
    case star
    case starEqual
    case static_
    case staticFieldIdentifier
    case string
    case super_
    case then
    case tilde
    case underscore
    case until
    case uppercaseIdentifier
    case var_
    case while_
    case xor
}
