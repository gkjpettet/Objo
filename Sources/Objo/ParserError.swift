//
//  ParserError.swift
//  
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

public struct ParserError: Error {
    public enum ErrorType {
        case unexpectedEndOfFile
    }
}
