//
//  String+Utilities.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//

import Foundation

extension String {

    var length: Int {
        return count
    }

    /// Returns the character at the specified position.
    ///
    /// //  Credit: https://stackoverflow.com/a/26775912/278816
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    /// Returns the substring from the 0-based position in this string to the end.
    /// If `fromIndex` exceeds the length of this string then an empty string is returned.
    ///
    /// //  Credit: https://stackoverflow.com/a/26775912/278816
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    /// Returns the substring from the start of this string for `toIndex` characters.
    /// If `toIndex` exceeds the last character then the entire string is returned.
    ///
    /// //  Credit: https://stackoverflow.com/a/26775912/278816
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    //  Credit: https://stackoverflow.com/a/26775912/278816
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
    /// If `substring` exists in this string we return the 0-based position of the first character of `substring`.
    /// If `substring` is not found in this string we return `-1`.
    func indexOf(substring: String, caseSensitive: Bool = true) -> Int {
        
        if caseSensitive {
            if let range = self.range(of: substring) {
                let index = self.distance(from: self.startIndex, to: range.lowerBound)
                return index
            } else {
                return -1
            }
        } else {
            if let range = self.range(of: substring, options: .caseInsensitive) {
                let index = self.distance(from: self.startIndex, to: range.lowerBound)
                return index
            } else {
                return -1
            }
        }
    }
    
    /// If `substring` exists in this string starting from 0-based position `from` we return the 0-based position of the first character of `substring`.
    /// If `substring` is not found in this string from the specified start position we return `-1`.
    func indexOf(substring: String, from: Int, caseSensitive: Bool = true) -> Int {
        if from > self.length {
            return self.indexOf(substring: substring, caseSensitive: caseSensitive)
        } else {
            let slice = String(self.suffix(self.length - from))
            return slice.indexOf(substring: substring, caseSensitive: caseSensitive) + from
        }
    }
    
    /// Returns the substring formed by started at 0-based position `start` for `length` characters.
    func substring(start: Int, length: Int) throws -> String {
        guard start >= 0, length >= 0, (start + length) <= self.length else {
            throw ObjoError.invalidArgument("Invalid arguments passed to `String.substring(start: length:)`.")
        }
        
        let startIndex = self.index(self.startIndex, offsetBy: start)
        let endIndex = self.index(startIndex, offsetBy: length)
        return String(self[startIndex..<endIndex])
    }
    
    /// Removes trailing whitespace from a string.
    /// 
    /// Credit: https://stackoverflow.com/a/59238738/278816
    @inline(__always)
    var trailingSpacesTrimmed: Self.SubSequence {
        var view = self[...]

        while view.last?.isWhitespace == true {
            view = view.dropLast()
        }

        return view
    }
}
