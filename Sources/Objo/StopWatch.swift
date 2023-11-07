//
//  StopWatch.swift
//
//
//  Created by Garry Pettet on 07/11/2023.
//
// A simple stopwatch class. Adapted from:
// https://medium.com/@pwilko/how-not-to-create-stopwatch-in-swift-e0b7ff98880f

import Foundation

public class Stopwatch {
    private var _startTime: Date?
    private var _accumulatedTime:TimeInterval = 0
    private var _isRunning = false
    
    public init(startImmediately: Bool = false) {
        start()
    }
    
    public var isRunning: Bool { return _isRunning }
    
    /// Start the stopwatch.
    func start() -> Void {
        _startTime = Date()
        _isRunning = true
    }
    
    /// Stop (pause) the stopwatch.
    func stop() -> Void {
        _accumulatedTime = self.elapsedTime()
        _startTime = nil
        _isRunning = false
    }
    
    /// Reset the stopwatch.
    func reset() -> Void {
        _accumulatedTime = 0
        _isRunning = false
        _startTime = nil
    }
    
    /// Returns the time interval between starting the stopwatch and now.
    func elapsedTime() -> TimeInterval {
        return -(_startTime?.timeIntervalSinceNow ?? 0) + _accumulatedTime
    }
}
