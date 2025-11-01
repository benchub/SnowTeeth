//
//  DebugLog.swift
//  SnowTeeth
//
//  Debug logging utilities that are automatically disabled in release builds.
//

import Foundation

/// Debug logging that only prints in DEBUG builds.
/// In release builds, these statements are completely removed by the compiler.
///
/// Usage:
///   debugLog("This message only appears in debug builds")
///   debugLog("Value: \(someValue)")
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

/// Error logging that always prints, even in release builds.
/// Use this for critical errors that should be logged in production.
///
/// Usage:
///   errorLog("Critical error: \(error)")
func errorLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    print("ERROR: \(output)", terminator: terminator)
}

/// Warning logging that always prints, even in release builds.
/// Use this for important warnings that should be logged in production.
///
/// Usage:
///   warningLog("GPS permission denied")
func warningLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    print("WARNING: \(output)", terminator: terminator)
}
