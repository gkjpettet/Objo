//
//  ListData.swift
//
//
//  Created by Garry Pettet on 20/11/2023.
//

import Foundation

public class ListData {
    /// The number of items in the array.
    public var count: Int { return items.count }
    
    /// The actual items in the array.
    public var items: [Value]
    
    /// The index of the last item in the array or `-1` if the list is empty.
    public var lastIndex: Int { return items.count - 1 }
    
    public init(items: [Value]? = nil) {
        self.items = items ?? []
    }
}
